import GetPut::*;
import LFSR::*;
import FIFO::*;
import StmtFSM::*;

// import Register::*;

// import MACPhyParameters::*;
// import ProtocolParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/register_library.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/rrr/remote_server_stub_PACKETGENRRR.bsh"
`include "asim/rrr/remote_server_stub_PACKETCHECKRRR.bsh"
`include "asim/rrr/remote_client_stub_PACKETCHECKRRR.bsh"

interface PacketGen;
  // for hooking up to the baseband
  interface Get#(TXVector) txVector;
  interface Get#(Bit#(8)) txData;
endinterface


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


// maybe parameterize by generation algorithm at some point
module [CONNECTED_MODULE] mkPacketGen (PacketGen);

  ServerStub_PACKETGENRRR serverStub <- mkServerStub_PACKETGENRRR();

  rule setRate;
    let rate <- serverStub.acceptRequest_SetRate();
  endrule

  rule setMax;
    let maxNew <- serverStub.acceptRequest_SetMaxLength();
  endrule

  rule setMin;
    let minNew <- serverStub.acceptRequest_SetMinLength();
  endrule

  rule setEnable;
    let enableNew <- serverStub.acceptRequest_SetEnable();
  endrule


  interface txVector = ?; 
  interface txData = ?; 

endmodule

// this one only checks packets for correctness, not 
// for sequence errors - might want to do that at some point
// even if it takes a while to re-sync
module [CONNECTED_MODULE] mkPacketCheck (PacketCheck);

 ServerStub_PACKETCHECKRRR serverStub <- mkServerStub_PACKETCHECKRRR();
 ClientStub_PACKETCHECKRRR clientStub <- mkClientStub_PACKETCHECKRRR();

 LFSR#(Bit#(16)) lfsr <- mkLFSR_16();
 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(13)) count <- mkReg(0);
 Reg#(Bit#(8)) checksum <- mkReg(0); 
 Reg#(Bool) initialized <- mkReg(False);
 FIFO#(RXVector) rxVectorFIFO <- mkFIFO; 
 FIFO#(Bit#(8))  rxDataFIFO <- mkFIFO; 
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

 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

 rule init(!initialized);
   initialized <= True;
   lfsr.seed(1);
 endrule

   rule checkPacketCheckState(`DEBUG_PACKETGEN == 1);
      if(cycleCountReg[9:0] == 0)
        begin
          $display("PacketGen: check size %d count %d",size,count);
        end
   endrule
   
   rule startPacketCheck(count == 0);
     rxVectorFIFO.deq;
     size <= rxVectorFIFO.first.header.length;
     clientStub.makeRequest_SendPacket(zeroExtend(pack(HEADER)),zeroExtend(rxVectorFIFO.first.header.length));
     count <= count + 1;
     checksum <= 0;
     if(`DEBUG_PACKETGEN == 1)
       begin
         $display("PacketGen: starting packet check size: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
       end
   endrule
   
   rule receiveData(count > 0 && count <= zeroExtend(size));
      rxDataFIFO.deq;
      if(`DEBUG_PACKETGEN == 1)
        begin
          $display("PacketGen: rxDataFIFO.first %d",rxDataFIFO.first);
        end
      clientStub.makeRequest_SendPacket(zeroExtend(pack(DATA)),zeroExtend(rxDataFIFO.first));
      count <= count + 1;
   endrule
   
   rule checkCheckSum(count > 0 && (count == zeroExtend(size) + 1));
      packetsRXReg <= packetsRXReg + 1;
      bytesRXReg <= bytesRXReg + zeroExtend(size);
      count <= 0;
      if(`DEBUG_PACKETGEN == 1)
        begin
          $display("PacketGen: Packet bit errors: %d, Packet bit length: %d, BER total: %d", packetBerReg, size*8, berReg);
        end
   endrule

  interface rxVector = fifoToPut(rxVectorFIFO);
  interface rxData = fifoToPut(rxDataFIFO);
  interface abortReq = fifoToGet(abortReqFIFO);
  interface abortAck = fifoToPut(abortAckFIFO);    

endmodule