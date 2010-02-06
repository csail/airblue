import GetPut::*;
import Connectable::*;

import ofdm_common::*;
import ofdm_parameters::*;
import ofdm_depuncturer::*;
import ofdm_viterbi::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import Parameters::*;
// import Viterbi::*;
// import Depuncturer::*;

// (* synthesize *)
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

// (* synthesize *)
module mkViterbiInstance(Viterbi#(RXGlobalCtrl,ViterbiInDataSz,
				  ViterbiOutDataSz));
   Viterbi#(RXGlobalCtrl,ViterbiInDataSz,ViterbiOutDataSz) viterbi;
   viterbi <- mkViterbi;
   return viterbi;
endmodule

module mkDecoder(Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
			  DecoderOutDataSz,Bit#(1)));
   // state elements
   let depuncturer <- mkDepuncturerInstance;
   let viterbi <- mkViterbiInstance;   
   
   // connections
   mkConnectionPrint("Dep -> Vit",depuncturer.out,viterbi.in);
   
   // methods
   interface in = depuncturer.in;
   interface out = viterbi.out;
endmodule
