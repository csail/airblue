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
 Reg#(Bit#(24))  packetDelayReg <- mkReg(0);
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

      txVectorFIFO.enq(TXVector{header:HeaderInfo{length:length, rate: unpack(rateReg), power:0, has_trailer: True}, pre_data:tagged Valid 0, post_data: tagged Valid 0});
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

   rule checkPacketCheckState(`DEBUG_PACKETGEN == 1);
      if(cycleCountReg[9:0] == 0)
        begin
          $display("PacketGen: check size %d count %d",size,count);
        end
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
                  if(`DEBUG_PACKETGEN == 1)
                    begin
                      $display("PacketGen: starting packet check size: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
                    end
               end
            else
               begin
                  waitAck <= True;
                  abortReqFIFO.enq(?);
                  if(`DEBUG_PACKETGEN == 1)
                    begin
                      $display("PacketGen: abort the packet: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
                    end
               end
         end
   endrule
   
   // drop data before we get back an ack
   rule dropData(waitAck);
      rxDataFIFO.deq;
      if(`DEBUG_PACKETGEN == 1)
        begin
          $display("PacketGen: drop data %d while waiting for ack @%d", rxDataFIFO.first, cycleCountReg);
        end
   endrule
   
   rule deqAbortAck(True);
      abortAckFIFO.deq;
      waitAck <= False;
      if(`DEBUG_PACKETGEN == 1)
        begin
          $display("PacketGen: abort completed according to receiver @ %d",cycleCountReg);
        end
   endrule
   
   rule receiveData(count > 0 && count <= zeroExtend(size));
      rxDataFIFO.deq;
      if(`DEBUG_PACKETGEN == 1)
        begin
          $display("PacketGen: rxDataFIFO.first %d",rxDataFIFO.first);
        end

      count <= count + 1;
      if(count == zeroExtend(size))
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.first)));  
            berReg <= berReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.first))); 
            if(`DEBUG_PACKETGEN == 1)
              begin 
                $display("PacketGen: receive data (checksum): %h @ %d",rxDataFIFO.first,cycleCountReg); 
              end
         end
      else
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.first)));  
            berReg <= berReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.first)));  
            if(`DEBUG_PACKETGEN == 1)
              begin
                $display("PacketGen: receive data: %h @ %d",rxDataFIFO.first,cycleCountReg);
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

            if(`DEBUG_PACKETGEN == 1)
              begin
                $display("PacketGen: receive packet count %d", packetsCorrectReg + 1);             
                $display("PacketGen: total bytes: %d", bytesRXReg + zeroExtend(size));
                $display("PacketGen: correctly received %d of %d packets @ %d",packetsCorrectReg,packetsRXReg,cycleCountReg);
              end
         end               
      else 
         begin
            $display("PacketGen: ERROR receive data(checksum): %h",checksum);
//            $finish;
         end  
             
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