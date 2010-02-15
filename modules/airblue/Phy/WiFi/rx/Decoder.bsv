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

import Clocks::*;
import GetPut::*;
import Connectable::*;

// import BCJR::*;
// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import ProtocolParameters::*;
// import Viterbi::*;
// import Depuncturer::*;

// import FIFOUtility::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_depuncturer.bsh"
`include "asim/provides/airblue_convolutional_decoder.bsh"
`include "asim/provides/fifo_utils.bsh"

// make a decoder with mkViterbi or mkBCJR?
//`define mkViterbi mkBCJR(viterbiMapCtrl)

(* synthesize *)
module mkDepuncturerInstance
   (Depuncturer#(RXGlobalCtrl,DepuncturerInDataSz,
		 DepuncturerOutDataSz,DepuncturerInBufSz,
		 DepuncturerOutBufSz));
   function DepunctData#(DepuncturerF1OutSz) dpp1
      (DepunctData#(DepuncturerF1InSz) x);
      return parDepunctFunc(dp1,x);
   endfunction
   
   function DepunctData#(DepuncturerF2OutSz) dpp2
      (DepunctData#(DepuncturerF2InSz) x);
      return parDepunctFunc(dp2,x);
   endfunction
   
   function DepunctData#(DepuncturerF3OutSz) dpp3
      (DepunctData#(DepuncturerF3InSz) x);
      return parDepunctFunc(dp3,x);
   endfunction
   
   Depuncturer#(RXGlobalCtrl,DepuncturerInDataSz,
		DepuncturerOutDataSz,DepuncturerInBufSz,
		DepuncturerOutBufSz) depuncturer;
   depuncturer <- mkDepuncturer(depuncturerMapCtrl,dpp1,dpp2,dpp3);
   return depuncturer;
endmodule

(* synthesize *)
module mkViterbiInstance(Viterbi#(RXGlobalCtrl,ViterbiInDataSz,
				  ViterbiOutDataSz));
   Viterbi#(RXGlobalCtrl,ViterbiInDataSz,ViterbiOutDataSz) viterbi;
//   viterbi <- `mkViterbi;
   viterbi <- mkConvDecoder(viterbiMapCtrl);
   return viterbi;
endmodule

module mkDecoder(Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
			  DecoderOutDataSz,ViterbiOutput));
   // state elements
   let depuncturer <- mkDepuncturerInstance;
   let viterbi <- mkViterbiInstance;   
   
   // connections
   mkConnection(depuncturer.out,viterbi.in);
   
   // methods
   interface in = depuncturer.in;
   interface out = viterbi.out;
endmodule


module mkDecoderMCD#(Clock fastClock, Reset fastReset) 
   (Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric, DecoderOutDataSz,ViterbiOutput));
   SyncFIFOIfc#(DecoderMesg#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric)) interfifo <- mkSyncFIFOFromCC(16,fastClock);
   let outfifo <- mkSyncFIFOToCC(16,fastClock,fastReset);

   // state elements
   let depuncturer <- mkDepuncturerInstance();
   let viterbi <- mkViterbiInstance(clocked_by fastClock, reset_by fastReset);   
   
   // connections
   mkConnection(syncFifoToGet(interfifo),viterbi.in);
   mkConnection(depuncturer.out,syncFifoToPut(interfifo));
   mkConnection(viterbi.out,syncFifoToPut(outfifo));   

   // methods
   interface in = depuncturer.in;
   interface out = syncFifoToGet(outfifo);
endmodule