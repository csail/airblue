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
import FIFOF::*;
import ClientServer::*;
import GetPut::*;
import Clocks::*;
import FixedPoint::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import ProtocolParameters::*;
// import FPGAParameters::*;
// import Receiver::*;
// import RXController::*;
// import LibraryFunctions::*;
// import FPComplex::*;
// import Synchronizer::*;
// import FPComplex::*;
// import MACPhyParameters::*;

// import CBusUtils::*;

//`include "../WiFiFPGA/Macros.bsv"

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/airblue_synchronizer.bsh"


interface WiFiReceiver;
   interface Put#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) in; // from DAC
   interface Get#(RXVector) outRXVector;
   interface Get#(Bit#(8))  outData;
   `ifdef SOFT_PHY_HINTS
   interface Get#(Bit#(8))  outSoftPhyHints;
   `endif
//   interface Get#(Synchronizer::ControlType) synchronizerStateUpdate;
   interface Get#(ControlType) synchronizerStateUpdate;
   interface ReadOnly#(CoarPowType) synchronizerCoarPower;
   interface Get#(RXExternalFeedback) packetFeedback;
   interface Get#(Bit#(0)) abortAck;
   method    Action        abortReq;
endinterface


module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkWiFiReceiver#( Clock viterbiClock, Reset viterbiReset, FFT#(Bool,FFTIFFTSz,RXFPIPrec,RXFPFPrec) fft) (WiFiReceiver);
   // state elements
   let rx_controller <- mkRXController;
   let synchronizer <- mkSynchronizerInstance;
   let unserializer <- mkUnserializerInstance;
   let channelEstimator <- mkChannelEstimatorInstance;
   
   // connections
   let receiver_preDescrambler <- mkReceiverPreDescramblerMCDInstance(viterbiClock,viterbiReset);
   let descrambler <- mkDescramblerInstance;

   // connections
   mkConnectionPrint("Sync -> Unse",synchronizer.synchronizer.out,unserializer.in);
   mkConnectionPrint("Unse -> FFT",unserializer.out,fft.in);
   mkConnectionPrint("FFT -> CEst",fft.out,channelEstimator.in);
   mkConnectionPrint("CEst -> RXCtrl0",channelEstimator.out,rx_controller.inFromPreDemapper);
   mkConnectionPrint("RXCtrl0 -> PreDes",rx_controller.outToPreDescrambler,receiver_preDescrambler.in);
   mkConnectionPrint("PreDes -> RXCtrl1",receiver_preDescrambler.out,rx_controller.inFromPreDescrambler);
   mkConnectionPrint("RXCtrl1 -> Desc",rx_controller.outToDescrambler,descrambler.in);
   mkConnectionPrint("Desc -> RXCtrl2",descrambler.out,rx_controller.inFromDescrambler);
   
   mkCBusWideRegR(valueof(AddrSynchronizerPower),synchronizer.coarPow);

   // methods
   interface Put in;
      method Action put(SynchronizerMesg#(RXFPIPrec,RXFPFPrec) mesg);
      synchronizer.synchronizer.in.put(mesg);
      $write("ReceiverHW: in:");
      fpcmplxWrite(4,mesg);
      $display("");
      endmethod
   endinterface
   interface Get outRXVector;  
     method ActionValue#(RXVector) get();
       let rxvector <- rx_controller.outRXVector.get;
       $display("ReceiverHW: outRXVector %d", rxvector.header.length); 
       return rxvector;
     endmethod
   endinterface
   interface Get outData;
     method ActionValue#(Bit#(8)) get();
       let data <- rx_controller.outData.get;
       $display("ReceiverHW: outData %h", data); 
       return data;
     endmethod
   endinterface 
   interface Get synchronizerStateUpdate = synchronizer.synchronizerStateUpdate; 
   interface synchronizerCoarPower = synchronizer.coarPow;
   interface packetFeedback = rx_controller.packetFeedback;
   interface abortAck = rx_controller.abortAck;
   method Action abortReq;
      rx_controller.abortReq.put(?);
   endmethod
   `ifdef SOFT_PHY_HINTS
   interface outSoftPhyHints = rx_controller.outSoftPhyHints;
   `endif
      
endmodule
