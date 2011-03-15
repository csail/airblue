import GetPut::*;
import LFSR::*;
import FIFO::*;
import FIFOLevel::*;
import StmtFSM::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/rrr/remote_server_stub_PACKETCHECKRRR.bsh"
`include "asim/rrr/remote_client_stub_PACKETCHECKRRR.bsh"
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/librl_bsv_base.bsh"

interface PacketCheck;
  // These functions reveal stats about the generator
  // for hooking up to the baseband
  interface Put#(RXVector) rxVector;
  interface Put#(Bit#(8))  rxData;
  interface Put#(Bit#(0))  abortAck;
  interface Get#(Bit#(0))  abortReq; 
endinterface


// Communications Enum
typedef enum { 
  HEADER = 0,
  DATA = 1
} PacketCheckCommand deriving(Bits,Eq);

typedef 8192 DataFIFOSize;

// this one only checks packets for correctness, not 
// for sequence errors - might want to do that at some point
// even if it takes a while to re-sync
module [CONNECTED_MODULE] mkPacketCheck (PacketCheck);

 ServerStub_PACKETCHECKRRR serverStub <- mkServerStub_PACKETCHECKRRR();
 ClientStub_PACKETCHECKRRR clientStub <- mkClientStub_PACKETCHECKRRR();

 // 8192 should be big enough for a few packets
 FIFOCountIfc#(Bit#(8),DataFIFOSize) rxDataFIFOIn <- mkSizedBRAMFIFOCount();
 FIFOCountIfc#(Bit#(8),DataFIFOSize) rxDataFIFOOut <- mkSizedBRAMFIFOCount();
 FIFOCountIfc#(RXVector,2048) rxVectorFIFO <- mkSizedBRAMFIFOCount();

 LFSR#(Bit#(16)) lfsr <- mkLFSR_16();
 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(13)) count <- mkReg(0);
 Reg#(Bit#(8)) checksum <- mkReg(0); 
 Reg#(Bool) initialized <- mkReg(False);
 FIFO#(Bit#(0))  abortReqFIFO <- mkFIFO;
 FIFO#(Bit#(0))  abortAckFIFO <- mkFIFO;  

 Reg#(Bit#(32)) packetsRXReg <- mkReg(0);
 Reg#(Bit#(32)) packetsCorrectReg <- mkReg(0);
 Reg#(Bit#(32)) bytesRXCorrectReg <- mkReg(0);
 Reg#(Bit#(32)) bytesRXReg <- mkReg(0);
 Reg#(Bit#(32)) cycleCountReg <- mkReg(0);
 Reg#(Bit#(32)) packetBerReg <- mkReg(0); // packetwise ber  
 Reg#(Bit#(32)) berReg <- mkReg(0);
 Reg#(Bool)     dropPacket <- mkReg(False); // dropped alternate packet
 Reg#(Bool)     dropThisPacket <- mkReg(False); // dropped alternate packet
 Reg#(Bool)     waitAck <- mkReg(False);


 rule getBER;
   let dummy <- serverStub.acceptRequest_GetBER();
   serverStub.sendResponse_GetBER(berReg);
 endrule

 rule getPacketRX;
   let dummy <- serverStub.acceptRequest_GetPacketsRX();
   serverStub.sendResponse_GetPacketsRX(packetsRXReg);
 endrule

 rule getPacketRXCorrect;
   let dummy <- serverStub.acceptRequest_GetPacketsRXCorrect();
   serverStub.sendResponse_GetPacketsRXCorrect(packetsCorrectReg);
 endrule

 rule setDropPacket;
   let dummy <- serverStub.acceptRequest_SetDropPacket();
   dropPacket <= unpack(truncate(dummy));
   serverStub.sendResponse_SetDropPacket(?);
 endrule

 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

 rule init(!initialized);
   initialized <= True;
   lfsr.seed(1);
 endrule

   rule checkPacketCheckState(`DEBUG_PACKETCHECK == 1);
      if(cycleCountReg[9:0] == 0)
        begin
          $display("PacketGen: check size %d count %d",size,count);
        end
   endrule
   
   rule startPacketCheck(count == 0);
     rxVectorFIFO.deq;
     size <= rxVectorFIFO.first.header.length;
     count <= count + 1;
     checksum <= 0;
     if(`DEBUG_PACKETCHECK == 1)
       begin
         $display("PacketCheck: starting packet check size: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
       end
     // Sometimes we won't attempt to send data to the host
     if(dropPacket && (unpack(zeroExtend(rxVectorFIFO.first.header.length)) > (fromInteger(valueof(DataFIFOSize) - 1) - rxDataFIFOOut.count)))
       begin
         $display("Packet Check: Dropping Packet");
         dropThisPacket <= True;
       end
     else 
       begin
         clientStub.makeRequest_SendPacket(zeroExtend(pack(HEADER)),zeroExtend({pack(rxVectorFIFO.first.header.rate),rxVectorFIFO.first.header.length}));
         dropThisPacket <= False;
       end
   endrule
   
   rule receiveData(count > 0 && count <= zeroExtend(size));
      rxDataFIFOIn.deq;
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: rxDataFIFO.first %d",rxDataFIFOIn.first);
        end
      if(!dropThisPacket) 
        begin
          rxDataFIFOOut.enq(rxDataFIFOIn.first());
        end
      count <= count + 1;
   endrule

   rule forwardData;
     rxDataFIFOOut.deq();
     clientStub.makeRequest_SendPacket(zeroExtend(pack(DATA)),zeroExtend(rxDataFIFOOut.first));
   endrule
   
   rule checkCheckSum(count > 0 && (count == zeroExtend(size) + 1));
      packetsRXReg <= packetsRXReg + 1;
      bytesRXReg <= bytesRXReg + zeroExtend(size);
      count <= 0;
      dropThisPacket <= False;
   endrule

  interface rxVector = toPut(rxVectorFIFO);
  interface rxData = toPut(rxDataFIFOIn);
  interface abortReq = fifoToGet(abortReqFIFO);
  interface abortAck = fifoToPut(abortAckFIFO);    

endmodule