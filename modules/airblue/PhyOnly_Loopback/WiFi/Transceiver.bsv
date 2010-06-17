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
`include "asim/provides/avalon.bsh"
`include "asim/provides/spi.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_phy_packet_gen.bsh"
`include "asim/provides/airblue_phy.bsh"
`include "asim/dict/AIRBLUE_REGISTER_MAP.bsh"
`include "asim/provides/analog_digital.bsh"
`include "asim/provides/gain_control.bsh"
`include "asim/provides/rf_frontend.bsh"


interface TransceiverASICWires;
  interface GCT_WIRES gctWires;      
  interface ADC_WIRES adcWires;
  interface DAC_WIRES dacWires;
endinterface

interface TransceiverFPGA;
  interface GCT_WIRES gctWires;      
  interface ADC_WIRES adcWires;
  interface DAC_WIRES dacWires;
  interface CBus#(AvalonAddressWidth,AvalonDataWidth) busWires;
endinterface

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkTransceiverPacketGenFPGAMonad#(Clock viterbiClock, Reset viterbiReset, Clock rfClock, Reset rfReset) (TransceiverASICWires);
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
   GCT_DEVICE  gct <- mkGCT;
   DAC_DEVICE  dac <- mkDAC(clock, reset, clocked_by rfClock, reset_by rfReset);
   ADC_DEVICE  adc <- mkADC(clock, reset, clocked_by rfClock, reset_by rfReset);
   AGC_DEVICE  agc <- mkAGC;


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


   // hook up TX controlflow
   rule txCompleteNotify;
     let in <- dac.dac_driver.txComplete;
     gct.gct_driver.txComplete.put(in);
     // Drive external completion signal
     // Drive it for a little bit longer than we expect to receive, just to ensure

   endrule


   // hook the Synchronizer to feedback points  
   rule synchronizerFeedback;
     ControlType ctrl <- transceiver.receiver.synchronizerStateUpdate.get;
     gct.gct_driver.synchronizerStateUpdate.put(ctrl);
     agc.agc_driver.synchronizerStateUpdate.put(ctrl);
     // update ctrl counts
     case (ctrl) 
      GainStart:  gainStart <= gainStart + 1;
      GHoldStart: gholdStart <= gholdStart + 1;
      TimeOut:    timeOut <= timeOut + 1;
      LongSync:   longSync <= longSync + 1;
     endcase

   endrule

   `ifdef SOFT_PHY_HINTS
   rule sinkHints;
      let ignore <- transceiver.receiver.outSoftPhyHints.get();
   endrule
   `endif

   // connect agc/rx ctrl
   rule packetFeedback;
     RXExternalFeedback feedback <- transceiver.receiver.packetFeedback.get;
     agc.agc_driver.packetFeedback.put(feedback); 
     gct.gct_driver.packetFeedback.put(feedback);

     case(feedback)
       Abort: begin 
                abort <= abort + 1;
                
              end
     endcase
   endrule


   // hook up the DAC/ADC
   mkConnection(transceiver.receiver.in,adc.adc_driver.dataIn);
   if(`DEBUG_TRANSCEIVER == 1)
      begin
         mkConnectionThroughput("CP->DAC",transceiver.transmitter.out,dac.dac_driver.dataOut);
      end
   else
      begin
         mkConnection(transceiver.transmitter.out,dac.dac_driver.dataOut);
      end
   
   rule sendGainToADC;
     dac.dac_driver.agcGainSet(agc.agc_driver.outputGain);
   endrule

   rule sendPowToAGC;
     agc.agc_driver.inputPower(transceiver.receiver.synchronizerCoarPower);
   endrule
   

   // Build up CReg interface   
   // Receiver Side   
   mkConnection(packetCheck.rxVector,transceiver.receiver.outRXVector);
   mkConnection(packetCheck.rxData,transceiver.receiver.outData);
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
      gct.gct_driver.txStart.put(txVec);
      dac.dac_driver.txStart.put(txVec); 
   endrule
   
   mkConnection(transceiver.transmitter.txData,packetGen.txData.get);   

  // GCT RF
  mkCBusPut(valueof(GCTOffset), gct.gct_driver.spiCommand);

 
  interface dacWires = dac.dac_wires;
  interface adcWires = adc.adc_wires;
  interface gctWires = gct.gct_wires;

endmodule

(* synthesize *)
module  mkTransceiverPacketGenFPGA#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;
   // do we want to line up the edges?
   // proabably need to set wait request during reset hold...
   Reset viterbiResetNew <- mkAsyncReset(2,rfReset,viterbiClock);
   Reset busResetNew <- mkAsyncReset(2,rfReset,busClock);
   Reset rfResetNew <- mkAsyncReset(2,rfReset,rfClock);
   Reset asicResetNew <- mkAsyncReset(2,rfReset,asicClock);

   let trans <- mkTransceiverPacketGenFPGAReset(viterbiClock, viterbiResetNew, busClock, busResetNew, rfClock, rfResetNew, clocked_by asicClock, reset_by asicResetNew);
   return trans;
endmodule

// We need a module to insert reset synchronizers
module [Module]  mkTransceiverPacketGenFPGAReset#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;

   // Build up CReg interface   
   let ifc <- exposeCBusIFC(mkTransceiverPacketGenFPGAMonad(viterbiClock,viterbiReset,rfClock, rfReset));

  interface gctWires = ifc.device_ifc.gctWires;      
  interface adcWires = ifc.device_ifc.adcWires;
  interface dacWires = ifc.device_ifc.dacWires;
  interface busWires = ifc.cbus_ifc;
endmodule

