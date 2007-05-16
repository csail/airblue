import Controls::*;
import DataTypes::*;
import Interfaces::*;
import Parameters::*;
import GetPut::*;
import Connectable::*;
import Viterbi::*;
import Depuncturer::*;
import ReedDecoder::*;

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
   depuncturer <- mkDepuncturer(puncturerMapCtrl,dpp1,dpp2,dpp3);
   return depuncturer;
endmodule

(* synthesize *)
module mkViterbiInstance(Viterbi#(RXGlobalCtrl,ViterbiInDataSz,
				  ViterbiOutDataSz));
   Viterbi#(RXGlobalCtrl,ViterbiInDataSz,ViterbiOutDataSz) viterbi;
   viterbi <- mkViterbi;
   return viterbi;
endmodule

(* synthesize *)
module mkReedDecoderInstance(ReedDecoder#(RXGlobalCtrl,ReedDecoderDataSz,
					  ReedDecoderDataSz));
   ReedDecoder#(RXGlobalCtrl,
		ReedDecoderDataSz,ReedDecoderDataSz) reedDecoder;
   reedDecoder <- mkReedDecoder(reedEncoderMapCtrl);
   return reedDecoder;
endmodule

module mkDecoder(Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
			  DecoderOutDataSz,Bit#(1)));
   // state elements
   let depuncturer <- mkDepuncturerInstance;
   let viterbi <- mkViterbiInstance;
   let reedDecoder <- mkReedDecoderInstance;
   
   // connections
   mkConnection(depuncturer.out,viterbi.in);
   mkConnection(viterbi.out,reedDecoder.in);
   
   // methods
   interface in = depuncturer.in;
   interface out = reedDecoder.out;
endmodule
