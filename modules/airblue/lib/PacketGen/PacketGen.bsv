import GetPut::*;
import LFSR::*;
import FIFO::*;
import StmtFSM::*;

import Register::*;

import MACPhyParameters::*;
import TXController::*;
import RXController::*;
import ProtocolParameters::*;


interface PacketGen;
  // These functions reveal stats about the generator
  interface Reg#(Bit#(1)) enablePacketGen; 
  interface ReadOnly#(Bit#(32)) packetsTX;
  interface ReadOnly#(Bit#(32)) cycleCount;
  interface Reg#(Bit#(12)) minPacketLength;  
  interface Reg#(Bit#(12)) maxPacketLength;
  interface Reg#(Bit#(12)) packetLengthMask;
  interface Reg#(Bit#(24)) packetDelay;  
  interface Reg#(Bit#(3)) rate;

  // for hooking up to the baseband
  interface Get#(TXVector) txVector;
  interface Get#(Bit#(8)) txData;
endinterface


interface PacketCheck;
  // These functions reveal stats about the generator
  interface ReadOnly#(Bit#(32)) packetsRX;
  interface ReadOnly#(Bit#(32)) packetsRXCorrect;
  interface ReadOnly#(Bit#(32)) bytesRX;
  interface ReadOnly#(Bit#(32)) bytesRXCorrect;
  interface ReadOnly#(Bit#(32)) cycleCount;
  interface ReadOnly#(Bit#(32)) ber;

  // for hooking up to the baseband
  interface Put#(RXVector) rxVector;
  interface Put#(Bit#(8))  rxData;
  interface Put#(Bit#(0))  abortAck;
  interface Get#(Bit#(0))  abortReq; 
endinterface



// maybe parameterize by generation algorithm at some point
(*synthesize*)
module mkPacketGen (PacketGen);
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
 Reg#(Bit#(12))  maxPacketLengthReg <- mkReg(255);
 Reg#(Bit#(12))  packetLengthMaskReg <- mkReg(~0);
 Reg#(Bit#(24))  packetDelayReg <- mkReg(0);
 Reg#(Bit#(24))  delayCount <- mkReg(0);
 Reg#(Bit#(3))   rateReg <- mkReg(4);

 rule init(!initialized);
   initialized <= True;
   lfsr.seed(1);
 endrule

 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

//  Stmt s = seq
//             action
//               Bit#(12) length = 1;
//               lfsr.next();
//               if((lfsr.value[11:0] & packetLengthMaskReg)> maxPacketLengthReg) 
//                 begin
//                   length = (maxPacketLengthReg == 0)? 1 : maxPacketLengthReg;
//                 end
//               else if((lfsr.value[11:0] & packetLengthMaskReg) < minPacketLengthReg) 
//                 begin
//                   length = (minPacketLengthReg == 0)? 1 : minPacketLengthReg;
//                 end 
//               else
//                 begin
//                   length = ((lfsr.value[11:0] & packetLengthMaskReg) == 0)? 1 : lfsr.value[11:0] & packetLengthMaskReg;
//                 end              
//               size <= length;
//               count <= 0;
//               checksum <= 0;
//               $display("PacketGen: starting packet gen size: %d",length);
//               txVectorFIFO.enq(TXVector{length:length, rate: unpack(rateReg), service:0,power:0});
//             endaction
//             while(count + 1 < zeroExtend(size))
//              action
//                $display("PacketGen: transmit data %h", count);
//                lfsr.next();
//                count <= count + 1;
//                txDataFIFO.enq(truncate(count));   
//                checksum <= checksum + truncate(count);
//              endaction
//             // reserve last byte for checksum
//              action
//                 $display("PacketGen: transmit data (checksum) %h", 0-checksum);
//                 txDataFIFO.enq(0-checksum);
//                 packetsTXReg <= packetsTXReg + 1;   
//                 $display("PacketGen: transmit packets count %d", packetsTXReg + 1);          
//              endaction
//              delayCount <= packetDelayReg;
//              while(delayCount > 0) 
//                action
//                  delayCount <= delayCount - 1;
//                endaction
//           endseq;

//   FSM fsm <- mkFSM(s);

//   rule makePackets(initialized && fsm.done && enable == 1);
//     fsm.start;
//   endrule

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
      $display("PacketGen: starting packet gen size: %d",length);
      txVectorFIFO.enq(TXVector{header:HeaderInfo{length:length, rate: unpack(rateReg), power:0, has_trailer: True}, pre_data:tagged Valid 0, post_data: tagged Valid 0});
   endrule
   
   rule transmitData(count > 0 && count < zeroExtend(size) && enable == 1);
      $display("PacketGen: transmit data %h", count);
      lfsr.next();
      count <= count + 1;
      txDataFIFO.enq(truncate(count-1));   
      checksum <= checksum + truncate(count-1);
   endrule

   rule transmitCheckSum(count > 0 && count == zeroExtend(size) && enable == 1);
      $display("PacketGen: transmit data (checksum) %h", 0-checksum);
      txDataFIFO.enq(0-checksum);
      packetsTXReg <= packetsTXReg + 1;   
      $display("PacketGen: transmit packets count %d", packetsTXReg + 1);          
      delayCount <= packetDelayReg;
      count <= 0;
   endrule

   rule decrDelayCount(delayCount > 0 && enable == 1);
      delayCount <= delayCount - 1;
   endrule            

  interface enablePacketGen = enable;
  interface minPacketLength = minPacketLengthReg;
  interface maxPacketLength = maxPacketLengthReg;
  interface packetLengthMask = packetLengthMaskReg;
  interface packetDelay = packetDelayReg;
  interface rate = rateReg;
  interface packetsTX = registerToReadOnly(packetsTXReg);
  interface cycleCount = registerToReadOnly(cycleCountReg);
  

  interface txVector = fifoToGet(txVectorFIFO);
  interface txData = fifoToGet(txDataFIFO);

endmodule

// this one only checks packets for correctness, not 
// for sequence errors - might want to do that at some point
// even if it takes a while to re-sync
(* synthesize *)
module mkPacketCheck (PacketCheck);
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


 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

 rule init(!initialized);
   initialized <= True;
   lfsr.seed(1);
 endrule

//  Stmt s = seq
//             action
//               lfsr.next();
//               rxVectorFIFO.deq;
//               size <= rxVectorFIFO.first.length;
//               count <= 0;
//               checksum <= 0;
//               $display("PacketGen: starting packet check size: %d", rxVectorFIFO.first.length);
//             endaction
//             while(count < zeroExtend(size)) // we count 0 length packets....
//              action
//                rxDataFIFO.deq;
//                count <= count + 1;
//                if(count + 1 == zeroExtend(size))
//                  begin
//                    berReg <= berReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.first)));  
//                    $display("PacketGen: receive data (checksum): %h",rxDataFIFO.first);
//                  end
//                else
//                  begin
//                    berReg <= berReg + pack(zeroExtend(countOnes(truncate(count)^rxDataFIFO.first)));  
//                   $display("PacketGen: receive data: %h",rxDataFIFO.first);
//                  end
//                checksum <= checksum + rxDataFIFO.first;
//              endaction
//             packetsRXReg <= packetsRXReg + 1;
//             bytesRXReg <= bytesRXReg + zeroExtend(size);
//             if(checksum == 0) 
//               action
//                 $display("PacketGen: receive packet count %d", packetsCorrectReg + 1);
//                 packetsCorrectReg <= packetsCorrectReg + 1;
//                 bytesRXCorrectReg <= bytesRXCorrectReg + zeroExtend(size);
//                 $display("PacketGen: total bytes: %d", bytesRXReg + zeroExtend(size));
//                 $display("PacketGen: correctly received %d of %d packets @ %d",packetsCorrectReg,packetsRXReg,cycleCountReg);
//               endaction               
//             else 
//               action
//                 $display("PacketGen: ERROR receive data(checksum): %h",checksum);
//                 $finish;
//               endaction               
//             $display("PacketGen: BER total: %d", berReg);
//           endseq;

//   FSM fsm <- mkFSM(s);

//   rule rxPackets(initialized && fsm.done);
//     fsm.start;
//   endrule

   rule checkPacketCheckState(True);
      $display("PacketGen: check size %d count %d",size,count);
   endrule
   
   rule checkRxDataFIFO(True);
      $display("PacketGen: rxDataFIFO.first %d",rxDataFIFO.first);
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
                  $display("PacketGen: starting packet check size: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
               end
            else
               begin
                  waitAck <= True;
                  abortReqFIFO.enq(?);
                  $display("PacketGen: abort the packet: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
               end
         end
   endrule
   
   // drop data before we get back an ack
   rule dropData(waitAck);
      rxDataFIFO.deq;
      $display("PacketGen: drop data %d while waiting for ack @%d", rxDataFIFO.first, cycleCountReg);
   endrule
   
   rule deqAbortAck(True);
      abortAckFIFO.deq;
      waitAck <= False;
      $display("PacketGen: abort completed according to receiver @ %d",cycleCountReg);
   endrule
   
   rule receiveData(count > 0 && count <= zeroExtend(size));
      rxDataFIFO.deq;
      count <= count + 1;
      if(count == zeroExtend(size))
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.first)));  
            berReg <= berReg + pack(zeroExtend(countOnes((~checksum + 1)^rxDataFIFO.first)));  
            $display("PacketGen: receive data (checksum): %h @ %d",rxDataFIFO.first,cycleCountReg);
         end
      else
         begin
            packetBerReg <= packetBerReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.first)));  
            berReg <= berReg + pack(zeroExtend(countOnes(truncate(count-1)^rxDataFIFO.first)));  
            $display("PacketGen: receive data: %h @ %d",rxDataFIFO.first,cycleCountReg);
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
            $display("PacketGen: receive packet count %d", packetsCorrectReg + 1);
            packetsCorrectReg <= packetsCorrectReg + 1;
            bytesRXCorrectReg <= bytesRXCorrectReg + zeroExtend(size);
            $display("PacketGen: total bytes: %d", bytesRXReg + zeroExtend(size));
            $display("PacketGen: correctly received %d of %d packets @ %d",packetsCorrectReg,packetsRXReg,cycleCountReg);
         end               
      else 
         begin
            $display("PacketGen: ERROR receive data(checksum): %h",checksum);
//            $finish;
         end               
      $display("PacketGen: Packet bit errors: %d, Packet bit length: %d, BER total: %d", packetBerReg, size*8, berReg);
   endrule

  interface packetsRX = registerToReadOnly(packetsRXReg);
  interface packetsRXCorrect = registerToReadOnly(packetsCorrectReg);
  interface bytesRX = registerToReadOnly(bytesRXReg);
  interface bytesRXCorrect = registerToReadOnly(bytesRXCorrectReg);
  interface cycleCount = registerToReadOnly(cycleCountReg);
  interface ber = registerToReadOnly(berReg);

  interface rxVector = fifoToPut(rxVectorFIFO);
  interface rxData = fifoToPut(rxDataFIFO);
  interface abortReq = fifoToGet(abortReqFIFO);
  interface abortAck = fifoToPut(abortAckFIFO);    

endmodule