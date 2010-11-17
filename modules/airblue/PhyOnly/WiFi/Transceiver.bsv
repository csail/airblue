//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

import Connectable::*;
import FIFO::*;
import GetPut::*;
import CBus::*;
import ModuleCollect::*;
import LFSR::*;
import ClientServer::*;
import Clocks::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_phy_packet_gen.bsh"
`include "asim/provides/airblue_phy.bsh"
`include "asim/dict/AIRBLUE_REGISTER_MAP.bsh"

interface TransceiverASICWires;
  // Put things in here that go to the top level (not CBus)
  interface Get#(DACMesg#(TXFPIPrec,TXFPFPrec)) basebandOut;
  interface Put#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) basebandIn;
endinterface

interface TransceiverFPGA;
  interface CBus#(AvalonAddressWidth,AvalonDataWidth) cbus_ifc;
  interface Get#(DACMesg#(TXFPIPrec,TXFPFPrec)) basebandOut;
  interface Put#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) basebandIn;
endinterface

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkTransceiverPacketGenFPGAMonad#(Clock viterbiClock, Reset viterbiReset) (TransceiverASICWires);
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;

   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerTimeOut = CRAddr{a: fromInteger(valueof(AddrSynchronizerTimeOut)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainHoldStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainHoldStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerLongSync = CRAddr{a: fromInteger(valueof(AddrSynchronizerLongSync)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXControlAbort = CRAddr{a: fromInteger(valueof(AddrRXControlAbort)) , o: 0};   

   // Fix me at some point
   Reg#(Bit#(32)) gainStart <- mkCBRegR(addrSynchronizerGainStart,0);
   Reg#(Bit#(32)) gholdStart<- mkCBRegR(addrSynchronizerGainHoldStart,0);
   Reg#(Bit#(32)) timeOut   <- mkCBRegR(addrSynchronizerTimeOut,0);
   Reg#(Bit#(32)) longSync <- mkCBRegR(addrSynchronizerLongSync,0);
   Reg#(Bit#(32)) abort <- mkCBRegR(addrRXControlAbort,0);

   WiFiTransceiver transceiver <- mkTransceiver(viterbiClock,viterbiReset);

   // packet gen crap
   PacketGen packetGen <- mkPacketGen;
   PacketCheck packetCheck <- mkPacketCheck;


   // packet Gen externals
   mkCBusWideRegRW(`AIRBLUE_REGISTER_MAP_ADDR_ENABLE_PACKET_GEN,packetGen.enablePacketGen);
   mkCBusWideRegR(valueof(AddrPacketsTX),packetGen.packetsTX);
   mkCBusWideRegRW(valueof(AddrMinPacketLength),packetGen.minPacketLength);
   mkCBusWideRegRW(valueof(AddrMaxPacketLength),packetGen.maxPacketLength);
   mkCBusWideRegRW(valueof(AddrPacketLengthMask),packetGen.packetLengthMask);
   mkCBusWideRegRW(valueof(AddrPacketDelay),packetGen.packetDelay);
   mkCBusWideRegRW(`AIRBLUE_REGISTER_MAP_ADDR_RATE,packetGen.rate);
   mkCBusWideRegR(valueof(AddrCycleCountTX),packetGen.cycleCount);

   // packet check externals
   mkCBusWideRegR(`AIRBLUE_REGISTER_MAP_ADDR_PACKETS_RX,packetCheck.packetsRX);
   mkCBusWideRegR(valueof(AddrPacketsRXCorrect),packetCheck.packetsRXCorrect);
   mkCBusWideRegR(valueof(AddrGetBytesRX),packetCheck.bytesRX);
   mkCBusWideRegR(valueof(AddrGetBytesRXCorrect),packetCheck.bytesRXCorrect);
   mkCBusWideRegR(`AIRBLUE_REGISTER_MAP_ADDR_BER,packetCheck.ber);


   // hook the Synchronizer to feedback points  
   rule synchronizerFeedback;
     ControlType ctrl <- transceiver.receiver.synchronizerStateUpdate.get;
     // maybe send this to physical layer
     // update ctrl counts
     case (ctrl) 
      GainStart:  gainStart <= gainStart + 1;
      GHoldStart: gholdStart <= gholdStart + 1;
      TimeOut:    timeOut <= timeOut + 1;
      LongSync:   longSync <= longSync + 1;
     endcase

   endrule
   
   // connect agc/rx ctrl
   rule packetFeedback;
     RXExternalFeedback feedback <- transceiver.receiver.packetFeedback.get;
     // possibly feed this one as well
     case(feedback)
       Abort: begin 
                abort <= abort + 1;
              end
     endcase
   endrule

   // Build up CReg interface   
   // Receiver Side   
   rule rxData;
      let data <- transceiver.receiver.outData.get();
      if(`DEBUG_TRANSCEIVER == 1)
         begin
           $display("Received: %h", data);
         end
      packetCheck.rxData.put(data);
   endrule

   mkConnection(packetCheck.rxVector,transceiver.receiver.outRXVector);
   mkConnection(packetCheck.abortAck,transceiver.receiver.abortAck);
   
   rule connectAbortReq (True);
      let dont_care <- packetCheck.abortReq.get;
      transceiver.receiver.abortReq;
   endrule

   // Transmitter Side
      

   rule txVecSend;
     // spread the tx vec love
      TXVector txVec <- packetGen.txVector.get;
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver: TX start");
         end
      transceiver.transmitter.txStart(txVec);
   endrule
   
   mkConnection(transceiver.transmitter.txData,packetGen.txData.get);   

   interface basebandIn = transceiver.receiver.in;
   interface basebandOut = transceiver.transmitter.out;

endmodule

(* synthesize *)
module  mkTransceiverPacketGenFPGA#(Clock viterbiClock, Reset viterbiReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;
   // do we want to line up the edges?
   // proabably need to set wait request during reset hold...
   Reset viterbiResetNew <- mkAsyncReset(2,asicReset,viterbiClock);

   let trans <- mkTransceiverPacketGenFPGAReset(viterbiClock, viterbiResetNew);
   return trans;
endmodule

// We need a module to insert reset synchronizers
module [Module]  mkTransceiverPacketGenFPGAReset#(Clock viterbiClock, Reset viterbiReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;

   // Build up CReg interface   
   let ifc <- exposeCBusIFC(mkTransceiverPacketGenFPGAMonad(viterbiClock,viterbiReset));


  interface cbus_ifc = ifc.cbus_ifc;
  interface basebandOut = ifc.device_ifc.basebandOut;
  interface basebandIn = ifc.device_ifc.basebandIn;
endmodule

