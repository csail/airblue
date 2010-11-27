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

// import ProtocolParameters::*;
// import FPGAParameters::*;
// import FFTIFFT::*;
// import WiFiReceiver::*;
// import WiFiTransmitter::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_fft.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"

interface WiFiTransceiver;
   interface WiFiTransmitter transmitter;
   interface WiFiReceiver receiver;
endinterface      

(* synthesize *)
module mkWiFiFFTIFFT (DualFFTIFFT#(Bool, TXGlobalCtrl, FFTIFFTSz,TXFPIPrec,TXFPFPrec));
   let wifiFFT <- mkDualFFTIFFTRR;  
   return wifiFFT;
endmodule

//(* synthesize *)
module [CONNECTED_MODULE] mkTransceiver#(Clock viterbiClock, Reset viterbiReset) (WiFiTransceiver);
   let wifiFFT <- mkWiFiFFTIFFT;
   let wifiTransmitter <- mkWiFiTransmitter(wifiFFT.ifft);
   let wifiReceiver    <- mkWiFiReceiver(viterbiClock, viterbiReset, wifiFFT.fft);

   interface transmitter = wifiTransmitter;
   interface receiver    = wifiReceiver;   
endmodule


