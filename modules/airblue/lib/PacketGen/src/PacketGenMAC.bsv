import GetPut::*;
import LFSR::*;
import FIFO::*;
import StmtFSM::*;

// import Register::*;

// import ProtocolParameters::*;
// import MACDataTypes::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/register_library.bsh"
`include "asim/provides/airblue_types.bsh"

interface MACPacketGen;
  // These functions reveal stats about the generator
  interface Reg#(Bit#(1)) enablePacketGen; 
  interface ReadOnly#(Bit#(32)) packetsTX;
  interface ReadOnly#(Bit#(32)) packetsAcked;
  interface ReadOnly#(Bit#(32)) cycleCount;
  interface Reg#(Bit#(12)) minPacketLength;  
  interface Reg#(Bit#(12)) maxPacketLength;
  interface Reg#(Bit#(12)) packetLengthMask;
  interface Reg#(Bit#(24)) packetDelay;  
  interface Reg#(Bit#(3)) rate; // Not useful...
  interface Put#(Bit#(48))   localMACAddress;
  interface Put#(Bit#(48))   targetMACAddress;

  // for hooking up to the baseband
  interface Get#(MacSWFrame) txVector;
  interface Get#(PhyData)    txData;
  interface Put#(MACTxStatus)    txStatus;
endinterface


interface MACPacketCheck;
  // These functions reveal stats about the generator
  interface ReadOnly#(Bit#(32)) packetsRX;
  interface ReadOnly#(Bit#(32)) packetsRXCorrect;
  interface ReadOnly#(Bit#(32)) bytesRX;
  interface ReadOnly#(Bit#(32)) cycleCount;


  // for hooking up to the baseband
  interface Put#(MacSWFrame) rxVector;
  interface Put#(PhyData)  rxData;
endinterface



// maybe parameterize by generation algorithm at some point
(*synthesize*)
module mkMACPacketGen (MACPacketGen);
 LFSR#(Bit#(16)) lfsr <- mkLFSR_16();
 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(13)) count <- mkReg(0);
 Reg#(Bit#(8)) checksum <- mkReg(0); 
 Reg#(Bool) initialized <- mkReg(False);
 Reg#(Bit#(1)) enable <- mkReg(0);
 FIFO#(MacSWFrame) txVectorFIFO <- mkFIFO; 
 FIFO#(Bit#(8))  txDataFIFO <- mkFIFO;
 FIFO#(MACTxStatus) txStatusFIFO <- mkFIFO; 
 Reg#(Bit#(32))  packetsTXReg <- mkReg(0);
 Reg#(Bit#(32))  packetsAckedReg <- mkReg(0);
 Reg#(Bit#(32))  cycleCountReg <- mkReg(0);
 Reg#(Bit#(12))  minPacketLengthReg <- mkReg(4000);
 Reg#(Bit#(12))  maxPacketLengthReg <- mkReg(4000);
 Reg#(Bit#(12))  packetLengthMaskReg <- mkReg(~0);
 Reg#(Bit#(24))  packetDelayReg <- mkReg(0);
 Reg#(Bit#(24))  delayCount <- mkReg(0);
 Reg#(Bit#(3))   rateReg <- mkReg(0);
 Reg#(Bit#(48))  localMAC <- mkReg(0);
 Reg#(Bit#(48))  targetMAC <- mkReg(0);

  // really must have knowledge of valid MACs 

 rule init(!initialized);
   initialized <= True;
   lfsr.seed(1);
 endrule

 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

 Stmt s = seq
            action
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
              DataFrame_T d1 = unpack(0); // make this a ? at some point
              $display("Generating new packet");
              d1.frame_ctl.prot_ver = 1;
              d1.frame_ctl.pwr_mgt = 0;
              d1.frame_ctl.type_val = Data;
              d1.frame_ctl.subtype_val = 0;
              d1.frame_ctl.more_frag = 0;
              d1.add1 = targetMAC;
              d1.add2 = localMAC;
              d1.seq_ctl.seq_num = truncate(length);
              MacSWFrame frame = MacSWFrame{frame: tagged Df d1, dataLength: length};
              size <= length;
              count <= 0;
              checksum <= 0;
              $display("TB PacketGen: starting packet gen size: %d",length);
              txVectorFIFO.enq(frame);
            endaction
            while(count + 1 < zeroExtend(size))
             action
               $display("TB PacketGen %d: transmit data %h", localMAC, lfsr.value[7:0]);
               lfsr.next();
               count <= count + 1;
               txDataFIFO.enq(truncate(count));   
               checksum <= checksum + truncate(count);
             endaction
            // reserve last byte for checksum
             action
               $display("TB PacketGen %d: transmit data (checksum) %h", localMAC, 0-checksum);
               txDataFIFO.enq(0-checksum);
               packetsTXReg <= packetsTXReg + 1;   
               $display("TB PacketGen: transmit packets count %d", packetsTXReg + 1);          
             endaction
            // XXX and now we need to check the TX status
             action
               txStatusFIFO.deq;
               if(txStatusFIFO.first == Success)
                 begin
                   $display("TB PacketGen Acked: %d ",packetsAckedReg);
                   packetsAckedReg <= packetsAckedReg+1;
                 end
               else
                 begin
                   $display("TB PacketGen Ack failure");
                 end
             endaction
             delayCount <= packetDelayReg;
             while(delayCount > 0) 
               action
                 delayCount <= delayCount - 1;
               endaction
          endseq;

  FSM fsm <- mkFSM(s);

  rule makePackets(initialized && fsm.done && enable == 1);
    $display("TB MAC %d starts tx fsm", localMAC);
    fsm.start;
  endrule

  interface enablePacketGen = enable;
  interface minPacketLength = minPacketLengthReg;
  interface maxPacketLength = maxPacketLengthReg;
  interface packetLengthMask = packetLengthMaskReg;
  interface packetDelay = packetDelayReg;
  interface rate = rateReg;
  interface packetsTX = registerToReadOnly(packetsTXReg);
  interface packetsAcked = registerToReadOnly(packetsAckedReg);
  interface cycleCount = registerToReadOnly(cycleCountReg);
  interface localMACAddress = registerToPut(localMAC);
  interface targetMACAddress = registerToPut(targetMAC);

  interface txVector = fifoToGet(txVectorFIFO);
  interface txData = fifoToGet(txDataFIFO);
  interface txStatus = fifoToPut(txStatusFIFO);
endmodule

// this one only checks packets for correctness, not 
// for sequence errors - might want to do that at some point
// even if it takes a while to re-sync
(* synthesize *)
module mkMACPacketCheck (MACPacketCheck);
 LFSR#(Bit#(16)) lfsr <- mkLFSR_16();
 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(12)) count <- mkReg(0);
 Reg#(Bit#(8)) checksum <- mkReg(0); 
 Reg#(Bool) initialized <- mkReg(False);
 FIFO#(MacSWFrame) rxVectorFIFO <- mkFIFO; 
 FIFO#(Bit#(8))  rxDataFIFO <- mkFIFO; 

 Reg#(Bit#(32)) packetsRXReg <- mkReg(0);
 Reg#(Bit#(32)) packetsCorrectReg <- mkReg(0);
 Reg#(Bit#(32)) bytesRXReg <- mkReg(0);
 Reg#(Bit#(32)) cycleCountReg <- mkReg(0);
 Reg#(Bit#(48)) localMAC <- mkReg(0);

 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

 rule init(!initialized);
   initialized <= True;
   lfsr.seed(1);
 endrule

 Stmt s = seq
            action
              lfsr.next();
              rxVectorFIFO.deq;
              size <= rxVectorFIFO.first.dataLength - fromInteger(valueof(DataFrameOctets));
              localMAC <= rxVectorFIFO.first.frame.Df.add1; 
              count <= 0;
              checksum <= 0;
              $display("PacketGen Check %d: starting packet check size: %d", localMAC, rxVectorFIFO.first.dataLength);
            endaction
            while(count < size) // we count 0 length packets....
             action
               rxDataFIFO.deq;
               $display("PacketGen Check%d: receive data[%d]: %h",localMAC,count,rxDataFIFO.first);
               count <= count + 1;
               checksum <= checksum + rxDataFIFO.first;
             endaction
            packetsRXReg <= packetsRXReg + 1;
            if(checksum == 0) 
              action
                $display("PacketGen Check %d: receive packet count %d", localMAC,packetsCorrectReg + 1);
                packetsCorrectReg <= packetsCorrectReg + 1;
                bytesRXReg <= bytesRXReg + zeroExtend(size);
                $display("PacketGen Check %d: total bytes: %d", localMAC, bytesRXReg + zeroExtend(size));
                $display("PacketGen Check %d: correctly received %d of %d packets",localMAC,packetsCorrectReg,packetsRXReg);
              endaction               
            else 
              action
                $display("PacketGen Check %d: ERROR receive data(checksum): %h",localMAC,checksum);
                $finish;
              endaction               
          endseq;

  FSM fsm <- mkFSM(s);

  rule rxPackets(initialized && fsm.done);
    fsm.start;
  endrule


  interface packetsRX = registerToReadOnly(packetsRXReg);
  interface packetsRXCorrect = registerToReadOnly(packetsCorrectReg);
  interface bytesRX = registerToReadOnly(bytesRXReg);
  interface cycleCount = registerToReadOnly(cycleCountReg);

  interface rxVector = fifoToPut(rxVectorFIFO);
  interface rxData = fifoToPut(rxDataFIFO);

endmodule