import GetPut::*;
import LFSR::*;
import FIFO::*;
import StmtFSM::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_PACKETGENRRR.bsh"
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/provides/fpga_components.bsh"

typedef enum {
  Idle,
  Sending,
  Waiting
} PacketGenState deriving (Bits,Eq);

interface PacketGen;
  // These functions reveal stats about the generator
  // for hooking up to the baseband
  interface Get#(TXVector) txVector;
  interface Get#(Bit#(8)) txData;
endinterface

// maybe parameterize by generation algorithm at some point
module [CONNECTED_MODULE] mkPacketGen (PacketGen);

 ServerStub_PACKETGENRRR serverStub <- mkServerStub_PACKETGENRRR();

 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(12)) sent  <- mkReg(0); 
 Reg#(PacketGenState) state <- mkReg(Idle);
 Reg#(Bit#(1)) enable <- mkReg(0);
 FIFO#(TXVector) txVectorFIFO <- mkFIFO; 
 FIFO#(Bit#(8))  txDataFIFO <- mkFIFO; 
 Reg#(Bit#(32))  packetsTXReg <- mkReg(0);
 Reg#(Bit#(32))  cycleCountReg <- mkReg(0);
 Reg#(Bit#(12))  lengthReg <- mkReg(1);
 Reg#(Bit#(24))  delay <- mkReg(0); // Delay each packet by 100us
 Reg#(Bit#(24))  delayCount <- mkReg(0);
 Reg#(Bit#(3))   rateReg <- mkReg(4);

 // Store packet info in a BRAM
 
 MEMORY_IFC#(Bit#(12),Bit#(8)) packetStore <- mkBRAM();

 rule setRate;
   let rate <- serverStub.acceptRequest_SetRate();
   rateReg <= truncate(rate);
 endrule

 rule setMax;
   let maxNew <- serverStub.acceptRequest_SetLength();
   lengthReg <= truncate(maxNew);   
 endrule

 rule setEnable;
   let enableNew <- serverStub.acceptRequest_SetEnable();
   enable <= truncate(enableNew);
 endrule

 rule setData;
   let bramCommand <- serverStub.acceptRequest_SetPacketByte();
   packetStore.write(truncate(bramCommand.addr), bramCommand.value);
 endrule

 rule setDelay;
   let delayNew <- serverStub.acceptRequest_SetDelay();
   delay <= truncate(delayNew);
 endrule

 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

 rule startPacketGen(state == Idle && enable == 1);
      size <= lengthReg;
      sent <= 0;
      if(`DEBUG_PACKETGEN == 1) 
        begin
          $display("PacketGen: starting packet gen size: %d",lengthReg);
        end

      txVectorFIFO.enq(TXVector{header:HeaderInfo{length:lengthReg, rate: unpack(rateReg), power:0, has_trailer: False}, pre_data:tagged Valid 0, post_data: tagged Valid 0});
      state <= Sending;
      delayCount <= delay;
   endrule
   
   rule transmitData(sent < size && state == Sending);
      if(`DEBUG_PACKETGEN == 1) 
        begin
          $display("PacketGen: transmit data %h", sent- 1);
        end

      sent <= sent + 1;
      packetStore.readReq(sent);

      if(sent + 1 == size)
        begin
          state <= Waiting;
        end
   endrule

   rule transmit;
      let data <- packetStore.readRsp();
      txDataFIFO.enq(data);   
   endrule

   rule decrDelayCount(state == Waiting);
      delayCount <= delayCount - 1;
      if(delayCount == 0)
        begin
          state <= Idle; 
        end
   endrule            

  interface txVector = fifoToGet(txVectorFIFO);
  interface txData = fifoToGet(txDataFIFO);

endmodule



