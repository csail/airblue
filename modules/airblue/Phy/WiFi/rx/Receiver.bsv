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
import GetPut::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_descrambler.bsh"
`include "asim/provides/airblue_deinterleaver.bsh"
`include "asim/provides/airblue_demapper.bsh"
`include "asim/provides/airblue_unserializer.bsh"
`include "asim/provides/airblue_channel_estimator.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"


module [CONNECTED_MODULE] mkSynchronizerInstance
   (GainControlSynchronizer#(SyncIntPrec,SyncFractPrec));
   GainControlSynchronizer#(SyncIntPrec,SyncFractPrec) block <- mkGainControlSynchronizer;
   return block;
endmodule

(* synthesize *)
module mkUnserializerInstance
   (Unserializer#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec));
   Unserializer#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec) block <- mkUnserializer;
   return block;
endmodule


(* synthesize *)
module mkChannelEstimatorInstance
   (ChannelEstimator#(Bool,CEstInDataSz,
		      CEstOutDataSz,RXFPIPrec,RXFPFPrec));
   ChannelEstimator#(Bool,CEstInDataSz,
		     CEstOutDataSz,RXFPIPrec,RXFPFPrec) block;
   block <- mkPiecewiseConstantChannelEstimator(resetPilot,
                                                pilotRemover,
                                                removePilotsAndGuards,
                                                inversePilotMapping,
                                                pilotPRBSMask,
                                                pilotInitSeq,
                                                getPilotLocs());
   return block;
endmodule

(* synthesize *)
module mkDemapperInstance
   (Demapper#(RXGlobalCtrl,DemapperInDataSz,DemapperOutDataSz,
	      RXFPIPrec,RXFPFPrec,ViterbiMetric));
   Demapper#(RXGlobalCtrl,DemapperInDataSz,DemapperOutDataSz,
	     RXFPIPrec,RXFPFPrec,ViterbiMetric) block;
   block <- mkDemapper(demodulationMapCtrl,demapperNegateOutput);
   return block;
endmodule

(* synthesize *)
module mkDeinterleaverInstance
   (Deinterleaver#(RXGlobalCtrl,DeinterleaverDataSz,
		   DeinterleaverDataSz,ViterbiMetric,MinNcbps));
   Deinterleaver#(RXGlobalCtrl,DeinterleaverDataSz,
		  DeinterleaverDataSz, ViterbiMetric,MinNcbps) block;
   block <- mkDeinterleaver(demodulationMapCtrl,deinterleaverGetIndex);
   return block;
endmodule

(* synthesize *)
module mkDecoderInstance
   (Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
	     DecoderOutDataSz,ViterbiOutput));
   Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
	    DecoderOutDataSz,ViterbiOutput) block;
   block <- mkDecoder;
   return block;
endmodule

(* synthesize *)
module mkDecoderMCDInstance#(Clock viterbiClock, Reset viterbiReset)
   (Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
	     DecoderOutDataSz,ViterbiOutput));
   Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
	    DecoderOutDataSz,ViterbiOutput) block;
   block <- mkDecoderMCD(viterbiClock,viterbiReset);
   return block;
endmodule
    

module mkReceiverPreDescramblerInstance
   (ReceiverPreDescrambler#(RXGlobalCtrl,DemapperInDataSz,RXFPIPrec,
			    RXFPFPrec,DecoderOutDataSz,ViterbiOutput));
    // state elements
    let demapper <- mkDemapperInstance;
    let deinterleaver <- mkDeinterleaverInstance;
    let decoder <- mkDecoderInstance;
    
    // connections
   if (`DEBUG_RXCTRL == 1)
      begin
         mkConnectionPrint("Dmap -> Dint",demapper.out,deinterleaver.in);
         mkConnectionPrint("Dint -> Deco",deinterleaver.out,decoder.in);
      end
   else
      begin
         mkConnection(demapper.out,deinterleaver.in);
         mkConnection(deinterleaver.out,decoder.in);
      end
    
    // methods
    interface in = demapper.in;
    interface out = decoder.out;
endmodule

module mkReceiverPreDescramblerMCDInstance#(Clock viterbiClock, Reset viterbiReset)
   (ReceiverPreDescrambler#(RXGlobalCtrl,DemapperInDataSz,RXFPIPrec,
			    RXFPFPrec,DecoderOutDataSz,ViterbiOutput));
    // state elements
    let demapper <- mkDemapperInstance;
    let deinterleaver <- mkDeinterleaverInstance;
    let decoder <- mkDecoderMCDInstance(viterbiClock, viterbiReset);
    
    // connections
   if (`DEBUG_RXCTRL == 1)
      begin
         mkConnectionPrint("Dmap -> Dint",demapper.out,deinterleaver.in);
         mkConnectionPrint("Dint -> Deco",deinterleaver.out,decoder.in);
      end
   else
      begin
         mkConnection(demapper.out,deinterleaver.in);
         mkConnection(deinterleaver.out,decoder.in);
      end
    
    // methods
    interface in = demapper.in;
    interface out = decoder.out;
endmodule

(* synthesize *)
module mkDescramblerInstance
   (Descrambler#(RXDescramblerAndGlobalCtrl,
		 DescramblerDataSz,DescramblerDataSz));
   Descrambler#(RXDescramblerAndGlobalCtrl,
		DescramblerDataSz,DescramblerDataSz) block;
   block <- mkDescrambler(descramblerMapCtrl,
			  descramblerGenPoly);
   return block;
endmodule

// (* synthesize *)
// module mkDescramblerInstance
//    (Descrambler#(RXDescramblerAndGlobalCtrl,
// 		 DescramblerDataSz,DescramblerDataSz));
//    Descrambler#(RXDescramblerAndGlobalCtrl,
// 		DescramblerDataSz,DescramblerDataSz) block;
//    block <- mkScrambler(descramblerMapCtrl,
// 			descramblerConvertCtrl,
// 			descramblerGenPoly);
//    return block;
// endmodule


