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
import AirblueTypes::*;
import AirblueCommon::*;
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/spi.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_phy_packet_gen.bsh"
`include "asim/provides/airblue_phy.bsh"
`include "asim/provides/analog_digital.bsh"
`include "asim/provides/gain_control.bsh"
`include "asim/provides/rf_frontend.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/soft_clocks.bsh"

interface TransceiverFPGA;
  interface GCT_WIRES gctWires;      
  interface ADC_WIRES adcWires;
  interface DAC_WIRES dacWires;
  interface Get#(RXVector) outRXVector;
  interface Get#(Bit#(8))  outRXData;
  interface Put#(TXVector) inTXVector;
  interface Put#(Bit#(8))  inTXData;  
endinterface

module [CONNECTED_MODULE] mkTransceiverPacketGenFPGA#(Clock viterbiClock, Reset viterbiReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;


   WiFiTransceiver transceiver <- mkTransceiver(viterbiClock,viterbiReset);

   let  gctBus <- liftModule(exposeCBusIFC(mkGCT));
   let  dacBus <- liftModule(exposeCBusIFC(mkDAC(clock, reset, clocked_by rfClock, reset_by rfReset)));
   let  adcBus <- liftModule(exposeCBusIFC(mkADC(clock, reset, clocked_by rfClock, reset_by rfReset)));
   let  agcBus <- liftModule(exposeCBusIFC(mkAGC));

   let  gct = gctBus.device_ifc;
   let  dac = dacBus.device_ifc;
   let  adc = adcBus.device_ifc;
   let  agc = agcBus.device_ifc;

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
   

  interface dacWires = dac.dac_wires;
  interface adcWires = adc.adc_wires;
  interface gctWires = gct.gct_wires;


  interface outRXVector = transceiver.receiver.outRXVector;
  interface outRXData = transceiver.receiver.outData;
  interface Put inTXVector;
    method Action put(TXVector txVec);
     // spread the tx vec love
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver: TX start");
         end
      transceiver.transmitter.txStart(txVec);
      gct.gct_driver.txStart.put(txVec);
      dac.dac_driver.txStart.put(txVec); 
    endmethod

  endinterface

  interface inTXData = toPut(transceiver.transmitter.txData);  

endmodule



