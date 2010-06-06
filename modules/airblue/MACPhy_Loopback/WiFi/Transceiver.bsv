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


// local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_phy.bsh"
`include "asim/provides/airblue_mac.bsh"
`include "asim/provides/airblue_mac_packet_gen.bsh"
`include "asim/dict/AIRBLUE_REGISTER_MAP.bsh"
`include "asim/provides/analog_digital.bsh"
`include "asim/provides/gain_control.bsh"
`include "asim/provides/rf_frontend.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/spi.bsh"


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

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkTransceiverMACPacketGenFPGAMonad#(Clock viterbiClock, Reset viterbiReset, Clock rfClock, Reset rfReset) (TransceiverASICWires);
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;

   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerTimeOut = CRAddr{a: fromInteger(valueof(AddrSynchronizerTimeOut)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainHoldStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainHoldStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerLongSync = CRAddr{a: fromInteger(valueof(AddrSynchronizerLongSync)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXControlAbort = CRAddr{a: fromInteger(valueof(AddrRXControlAbort)) , o: 0};   
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrPhyPacketsRX = CRAddr{a: fromInteger(valueof(AddrPhyPacketsRX)) , o: 0};   
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACAbort = CRAddr{a: fromInteger(valueof(AddrMACAbort)) , o: 0};   

   // Fix me at some point
   Reg#(Bit#(32)) gainStart <- mkCBRegR(addrSynchronizerGainStart,0);
   Reg#(Bit#(32)) gholdStart<- mkCBRegR(addrSynchronizerGainHoldStart,0);
   Reg#(Bit#(32)) timeOut   <- mkCBRegR(addrSynchronizerTimeOut,0);
   Reg#(Bit#(32)) longSync <- mkCBRegR(addrSynchronizerLongSync,0);
   Reg#(Bit#(32)) abort <- mkCBRegR(addrRXControlAbort,0);
   Reg#(Bit#(32)) phyPacketsRX <- mkCBRegR(addrPhyPacketsRX,0);
   Reg#(Bit#(32)) macAbort <- mkCBRegR(addrMACAbort,0);
   

   Reg#(Bit#(64)) csmaIdle <- mkReg(0);
//   Empty  csmaIdleWrapper <- mkCBusWideRegR(valueof(AddrCyclesCSMAIdle),registerToReadOnly(csmaIdle));
   Reg#(Bit#(64)) csmaBusy <- mkReg(0);
//   Empty  csmaBusyWrapper <- mkCBusWideRegR(valueof(AddrCyclesCSMABusy),registerToReadOnly(csmaBusy));


   WiFiTransceiver transceiver <- mkTransceiver(viterbiClock, viterbiReset);
   MAC  mac <- mkMAC;
   GCT_DEVICE  gct <- mkGCT;
   DAC_DEVICE  dac <- mkDAC(clock, reset, clocked_by rfClock, reset_by rfReset);
   ADC_DEVICE  adc <- mkADC(clock, reset, clocked_by rfClock, reset_by rfReset);
   AGC_DEVICE  agc <- mkAGC;


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


   // Hook mac to the transceiver
   mkConnection( transceiver.transmitter.txData, mac.phy_txdata.get);
   mkConnection( transceiver.receiver.outData, mac.phy_rxdata);
   mkConnection(mac.abortAck,transceiver.receiver.abortAck);
   
   rule connectAbortReq (True);
      let dont_care <- mac.abortReq.get;
      transceiver.receiver.abortReq;
   endrule
   
   rule countPhyPackets;
     let vec <- transceiver.receiver.outRXVector.get;
     mac.phy_rxstart.put(vec);
     phyPacketsRX <= phyPacketsRX + 1;
   endrule    

   rule txVecSend;
     TXVector txVec <- mac.phy_txstart.get;
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver: TX start");
         end
     transceiver.transmitter.txStart(txVec);
     gct.gct_driver.txStart.put(txVec);
     dac.dac_driver.txStart.put(txVec); 
   endrule
   
 
   // CS decision
   //false positives may be an issue.
   // BUSY if we are transmitting or if AGC is doing things
   rule driveCS;
     let status <- gct.gct_driver.rxBusy.get;
     if(status) 
       begin
         csmaBusy <= csmaBusy + 1;
         mac.phy_cca_ind.put(BUSY);
       end
     else
       begin
         csmaIdle <= csmaIdle + 1;
         mac.phy_cca_ind.put(IDLE);
       end
   endrule


  //A second rule for handling the case that the MAC decides the packet is corrupt
  rule maccrcFeedback;
    RXExternalFeedback feedback <- mac.mac_abort.get;   
    macAbort <= macAbort + 1;
    if (`DEBUG_TRANSCEIVER == 1)
      begin
        $display("Transceiver: MAC abort: %d", macAbort+1);
      end
  endrule

  // Setup the packet gen
  MACPacketGen packetGen <- mkMACPacketGen;
  MACPacketCheck packetCheck <- mkMACPacketCheck; 

  // hook packet gen/check to mac
  mkConnection(packetCheck.rxVector, mac.mac_sw_rxframe);    
  mkConnection(packetCheck.rxData, mac.mac_sw_rxdata);    
  mkConnection(mac.mac_sw_txframe,packetGen.txVector);   
  mkConnection(mac.mac_sw_txdata,packetGen.txData);   
  mkConnection(packetGen.txStatus,mac.mac_sw_txstatus);   

  // Setup the mac i/o
   
  mkCBusPut(valueof(MACAddrOffset), mac.mac_sa);
  mkCBusPut(valueof(MACAddrOffset), packetGen.localMACAddress);
  mkCBusPut(valueof(TargetMACAddrOffset), packetGen.targetMACAddress);

  // packet Gen externals
  mkCBusWideRegRW(`AIRBLUE_REGISTER_MAP_ADDR_ENABLE_PACKET_GEN,packetGen.enablePacketGen);
  mkCBusWideRegR(valueof(AddrPacketsTX),packetGen.packetsTX);
  mkCBusWideRegR(valueof(AddrPacketsAcked),packetGen.packetsAcked);
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

  // GCT RF
  mkCBusPut(valueof(GCTOffset), gct.gct_driver.spiCommand);

  interface gctWires = gct.gct_wires;
  interface adcWires = adc.adc_wires;
  interface dacWires = dac.dac_wires;

endmodule

/* This has become excessive.  we must REALLY refactor this crap. That this module is more than 500 lines is pretty ridiculous.  */
(* synthesize *)
module mkTransceiverMACPacketGenFPGA#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;
   // do we want to line up the edges?
   // proabably need to set wait request during reset hold...
   Reset viterbiResetNew <- mkAsyncReset(2,rfReset,viterbiClock);
   Reset busResetNew <- mkAsyncReset(2,rfReset,busClock);
   Reset rfResetNew <- mkAsyncReset(2,rfReset,rfClock);
   Reset asicResetNew <- mkAsyncReset(2,rfReset,asicClock);

   let trans <- mkTransceiverMACPacketGenFPGAReset(viterbiClock, viterbiResetNew, busClock, busResetNew, rfClock, rfResetNew, clocked_by asicClock, reset_by asicResetNew);
   return trans;
endmodule

// We need a module to insert reset synchronizers
module [Module] mkTransceiverMACPacketGenFPGAReset#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;

   // Build up CReg interface   
   let ifc <- exposeCBusIFC(mkTransceiverMACPacketGenFPGAMonad(viterbiClock,viterbiReset,rfClock, rfReset));

  interface gctWires = ifc.device_ifc.gctWires;      
  interface adcWires = ifc.device_ifc.adcWires;
  interface dacWires = ifc.device_ifc.dacWires;
  interface busWires = ifc.cbus_ifc;
endmodule
