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

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"


interface WiFiTransmitter;
   method Action txStart(TXVector txVec);    // fromMAC (length, rate, service, power) ~34 bits
   method Action txData(Bit#(8) inData);    // fromMAC
   method Action txEnd();                    // fromMAC
   interface Get#(DACMesg#(TXFPIPrec,TXFPFPrec)) out; // to DAC
endinterface


module [CONNECTED_MODULE] mkWiFiTransmitter#(IFFT#(TXGlobalCtrl,FFTIFFTSz,TXFPIPrec,TXFPFPrec) ifft) (WiFiTransmitter);
   // state element
   let tx_controller <- mkTXController;
   let transmitter <- mkTransmitterInstance(ifft);
   
   // make connection
   mkConnection(tx_controller.out,transmitter.in);
   
   // methods
   method Action txStart(TXVector txVec);
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("Transmitter: txStart called length: %d", txVec.header.length);
         end
      tx_controller.txStart(txVec);
   endmethod
   
   method Action txData(Bit#(8) inData);
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("TransmitterHW: txData called: %h", inData);
         end
      tx_controller.txData(inData);
   endmethod
   
   method Action txEnd();
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("Transmitter: txEnd called");
         end
      tx_controller.txEnd;
   endmethod
   
   interface out = transmitter.out;
endmodule

