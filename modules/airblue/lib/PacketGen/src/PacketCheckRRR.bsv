import GetPut::*;
import LFSR::*;
import FIFO::*;
import StmtFSM::*;

// import Register::*;

// import MACPhyParameters::*;
// import ProtocolParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_PACKETCHECKRRR.bsh"


// this one only checks packets for correctness, not 
// for sequence errors - might want to do that at some point
// even if it takes a while to re-sync
module [CONNECTED_MODULE] mkPacketCheck (Empty);

 ServerStub_PACKETCHECKRRR serverStub <- mkServerStub_PACKETCHECKRRR();

 LFSR#(Bit#(16)) lfsr <- mkLFSR_16();
 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(13)) count <- mkReg(0);
 Reg#(Bit#(8)) checksum <- mkReg(0); 
 Reg#(Bool) initialized <- mkReg(False);
 Connection_Receive#(RXVector) rxVectorFIFO <- mkConnection_Receive("RXVector"); 
 Connection_Receive#(Bit#(8))  rxDataFIFO <- mkConnection_Receive("RXData"); 
 Connection_Send#(Bit#(1))  abortReqFIFO <-mkConnection_Send("AbortReq");
 Connection_Receive#(Bit#(1))  abortAckFIFO <- mkConnection_Receive("AbortAck");  

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

 rule getBytesRX;
   let dummy <- serverStub.acceptRequest_GetBytesRX();
   serverStub.sendResponse_GetBytesRX(bytesRXReg);
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
      if (!rxVectorFIFO.receive.is_trailer) // only check if not trailer
         begin
//            dropPacket <= !dropPacket;
            if (!dropPacket)
               begin
                  lfsr.next();
                  size <= rxVectorFIFO.receive.header.length;
                  count <= count + 1;
                  checksum <= 0;
                  if(`DEBUG_PACKETCHECK == 1)
                    begin
                      $display("PacketCheck: starting packet check size: %d @ %d", rxVectorFIFO.receive.header.length, cycleCountReg);
                    end
               end
            else
               begin
                  waitAck <= True;
                  abortReqFIFO.send(?);
                  if(`DEBUG_PACKETCHECK == 1)
                    begin
                      $display("PacketCheck: abort the packet: %d @ %d", rxVectorFIFO.receive.header.length, cycleCountReg);
                    end
               end
         end
   endrule
   
   // drop data before we get back an ack
   rule dropData(waitAck);
      rxDataFIFO.deq;
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: drop data %d while waiting for ack @%d", rxDataFIFO.receive, cycleCountReg);
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
          $display("PacketCheck: rxDataFIFO.receive %d",rxDataFIFO.receive);
        end

      count <= count + 1;
      if(count == zeroExtend(size))
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.receive)));  
            berReg <= berReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.receive))); 
            if(`DEBUG_PACKETCHECK == 1)
              begin 
                $display("PacketCheck: receive data (checksum): %h @ %d",rxDataFIFO.receive,cycleCountReg); 
              end
         end
      else
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.receive)));  
            berReg <= berReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.receive)));  
            if(`DEBUG_PACKETCHECK == 1)
              begin
                $display("PacketCheck: receive data: %h @ %d",rxDataFIFO.receive,cycleCountReg);
              end
         end
      checksum <= checksum + rxDataFIFO.receive;
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

endmodule