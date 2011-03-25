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
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_PACKETCHECKRRR.bsh"

interface PacketCheck;
  // These functions reveal stats about the generator
  //interface ReadOnly#(Bit#(32)) packetsRX;
  //interface ReadOnly#(Bit#(32)) packetsRXCorrect;
  //interface ReadOnly#(Bit#(32)) bytesRX;
  //interface ReadOnly#(Bit#(32)) bytesRXCorrect;
  //interface ReadOnly#(Bit#(32)) cycleCount;
  //interface ReadOnly#(Bit#(32)) ber;

  // for hooking up to the baseband
  interface Put#(RXVector) rxVector;
  interface Put#(Bit#(8))  rxData;
  interface Put#(Bit#(0))  abortAck;
  interface Get#(Bit#(0))  abortReq; 
endinterface



// this one only checks packets for correctness, not 
// for sequence errors - might want to do that at some point
// even if it takes a while to re-sync
module [CONNECTED_MODULE] mkPacketCheck (PacketCheck);

 ServerStub_PACKETCHECKRRR serverStub <- mkServerStub_PACKETCHECKRRR();

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

   
   rule startPacketCheck(count == 0);
      rxVectorFIFO.deq;
      if (!rxVectorFIFO.first.is_trailer) // only check if not trailer
         begin
//            dropPacket <= !dropPacket;
            if (!dropPacket)
               begin
                  lfsr.next();
                  size <= rxVectorFIFO.first.header.length;
                  count <= count + 1;
                  checksum <= 0;
                  if(`DEBUG_PACKETCHECK == 1)
                    begin
                      $display("PacketCheck: starting packet check size: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
                    end
               end
            else
               begin
                  waitAck <= True;
                  abortReqFIFO.enq(?);
                  if(`DEBUG_PACKETCHECK == 1)
                    begin
                      $display("PacketCheck: abort the packet: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
                    end
               end
         end
   endrule
   
   // drop data before we get back an ack
   rule dropData(waitAck);
      rxDataFIFO.deq;
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: drop data %d while waiting for ack @%d", rxDataFIFO.first, cycleCountReg);
        end
   endrule
   
   rule deqAbortAck(True);
      abortAckFIFO.deq;
      waitAck <= False;
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: abort completed according to receiver @ %d",cycleCountReg);
        end
   endrule
   
   rule receiveData(count > 0 && count <= zeroExtend(size));
      rxDataFIFO.deq;
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: rxDataFIFO.first %d",rxDataFIFO.first);
        end

      count <= count + 1;
      if(count == zeroExtend(size))
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.first)));  
            berReg <= berReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.first))); 
            if(`DEBUG_PACKETCHECK == 1)
              begin 
                $display("PacketCheck: receive data (checksum): %h @ %d",rxDataFIFO.first,cycleCountReg); 
              end
         end
      else
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.first)));  
            berReg <= berReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.first)));  
            if(`DEBUG_PACKETCHECK == 1)
              begin
                $display("PacketCheck: receive data: %h @ %d",rxDataFIFO.first,cycleCountReg);
              end
         end
      checksum <= checksum + rxDataFIFO.first;
   endrule
   
   rule checkCheckSum(count > 0 && (count == zeroExtend(size) + 1));
      packetsRXReg <= packetsRXReg + 1;
      bytesRXReg <= bytesRXReg + zeroExtend(size);
      count <= 0;
      packetBerReg <= 0; // reset packetwise ber
      if(checksum == 0) 
         begin
            packetsCorrectReg <= packetsCorrectReg + 1;
            bytesRXCorrectReg <= bytesRXCorrectReg + zeroExtend(size);

            if(`DEBUG_PACKETCHECK == 1)
              begin
                $display("PacketCheck: receive packet count %d", packetsCorrectReg + 1);             
                $display("PacketCheck: total bytes: %d", bytesRXReg + zeroExtend(size));
                $display("PacketCheck: correctly received %d of %d packets @ %d",packetsCorrectReg,packetsRXReg,cycleCountReg);
              end
         end               
      else 
         begin
            $display("PacketCheck: ERROR receive data(checksum): %h",checksum);
//            $finish;
         end  
             
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: Packet bit errors: %d, Packet bit length: %d, BER total: %d", packetBerReg, size*8, berReg);
        end

   endrule

  interface rxVector = fifoToPut(rxVectorFIFO);
  interface rxData = fifoToPut(rxDataFIFO);
  interface abortReq = fifoToGet(abortReqFIFO);
  interface abortAck = fifoToPut(abortAckFIFO);    

endmodule