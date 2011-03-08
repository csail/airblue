import GetPut::*;
import LFSR::*;
import FIFO::*;
import StmtFSM::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/register_library.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_PACKETGENRRR.bsh"

interface PacketGen;
  // These functions reveal stats about the generator
  //interface Reg#(Bit#(1)) enablePacketGen; 
  //interface ReadOnly#(Bit#(32)) packetsTX;
  //interface ReadOnly#(Bit#(32)) cycleCount;
  //interface Reg#(Bit#(12)) minPacketLength;  
  //interface Reg#(Bit#(12)) maxPacketLength;
  //interface Reg#(Bit#(12)) packetLengthMask;
  //interface Reg#(Bit#(24)) packetDelay;  
  //interface Reg#(Bit#(3)) rate;

  // for hooking up to the baseband
  interface Get#(TXVector) txVector;
  interface Get#(Bit#(8)) txData;
endinterface

// maybe parameterize by generation algorithm at some point
module [CONNECTED_MODULE] mkPacketGen (PacketGen);

 ServerStub_PACKETGENRRR serverStub <- mkServerStub_PACKETGENRRR();

 LFSR#(Bit#(16)) lfsr <- mkLFSR_16();
 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(13)) count <- mkReg(0);
 Reg#(Bit#(8)) checksum <- mkReg(0); 
 Reg#(Bool) initialized <- mkReg(False);
 Reg#(Bit#(1)) enable <- mkReg(0);
 FIFO#(TXVector) txVectorFIFO <- mkFIFO; 
 FIFO#(Bit#(8))  txDataFIFO <- mkFIFO; 
 Reg#(Bit#(32))  packetsTXReg <- mkReg(0);
 Reg#(Bit#(32))  cycleCountReg <- mkReg(0);
 Reg#(Bit#(12))  minPacketLengthReg <- mkReg(1);
 Reg#(Bit#(12))  maxPacketLengthReg <- mkReg(~0);
 Reg#(Bit#(12))  packetLengthMaskReg <- mkReg(~0);
 Reg#(Bit#(24))  packetDelayReg <- mkReg(0); // Delay each packet by 100us
 Reg#(Bit#(24))  delayCount <- mkReg(0);
 Reg#(Bit#(3))   rateReg <- mkReg(4);

 rule setRate;
   let rate <- serverStub.acceptRequest_SetRate();
   rateReg <= truncate(rate);
   //serverStub.sendResponse_GetBER(berReg);
 endrule

 rule setMax;
   let maxNew <- serverStub.acceptRequest_SetMaxLength();
   maxPacketLengthReg <= truncate(maxNew);
   //serverStub.sendResponse_GetBER(berReg);
 endrule

 rule setMin;
   let minNew <- serverStub.acceptRequest_SetMinLength();
   minPacketLengthReg <= truncate(minNew);
   //serverStub.sendResponse_GetBER(berReg);
 endrule

 rule setEnable;
   let enableNew <- serverStub.acceptRequest_SetEnable();
   enable <= truncate(enableNew);
   //serverStub.sendResponse_GetBER(berReg);
 endrule

 rule init(!initialized);
   initialized <= True;
   lfsr.seed(1);
 endrule

 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

   rule startPacketGen(delayCount == 0 && count == 0 && enable == 1);
      Bit#(12) length = 1;
      lfsr.next();
      if((lfsr.value[11:0] & packetLengthMaskReg)> maxPacketLengthReg) 
         begin
            length = (maxPacketLengthReg == 0)? 1 : maxPacketLengthReg;
         end
      else if((lfsr.value[11:0] & packetLengthMaskReg) < minPacketLengthReg) 
         begin
            length = (minPacketLengthReg == 0)? 1 : minPacketLengthReg;
         end 
      else
         begin
            length = ((lfsr.value[11:0] & packetLengthMaskReg) == 0)? 1 : lfsr.value[11:0] & packetLengthMaskReg;
         end       

      size <= length;
      count <= count + 1;
      checksum <= 0;

      if(`DEBUG_PACKETGEN == 1) 
        begin
          $display("PacketGen: starting packet gen size: %d",length);
        end

      txVectorFIFO.enq(TXVector{header:HeaderInfo{length:length, rate: unpack(rateReg), power:0, has_trailer: False}, pre_data:tagged Valid 0, post_data: tagged Valid 0});
   endrule
   
   rule transmitData(count > 0 && count < zeroExtend(size) && enable == 1);
      if(`DEBUG_PACKETGEN == 1) 
        begin
          $display("PacketGen: transmit data %h", count - 1);
        end

      lfsr.next();
      count <= count + 1;
      txDataFIFO.enq(truncate(count-1));   
      checksum <= checksum + truncate(count-1);
   endrule

   rule transmitCheckSum(count > 0 && count == zeroExtend(size) && enable == 1);
      if(`DEBUG_PACKETGEN == 1) 
        begin
          $display("PacketGen: transmit data (checksum) %h", 0-checksum);
        end

      txDataFIFO.enq(0-checksum);
      packetsTXReg <= packetsTXReg + 1;   
    
      if(`DEBUG_PACKETGEN == 1) 
        begin
          $display("PacketGen: transmit packets count %d", packetsTXReg + 1);
        end
      delayCount <= packetDelayReg;
      count <= 0;
   endrule

   rule decrDelayCount(delayCount > 0 && enable == 1);
      delayCount <= delayCount - 1;
   endrule            

  interface txVector = fifoToGet(txVectorFIFO);
  interface txData = fifoToGet(txDataFIFO);

endmodule



