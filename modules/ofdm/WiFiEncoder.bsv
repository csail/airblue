import Controls::*;
import DataTypes::*;
import Interfaces::*;
import Parameters::*;
import GetPut::*;
import Connectable::*;
import ConvEncoder::*;
import Puncturer::*;

(* synthesize *)
module mkConvEncoderInstance(ConvEncoder#(TXGlobalCtrl,ConvEncoderInDataSz,
					  ConvEncoderOutDataSz));
   ConvEncoder#(TXGlobalCtrl,ConvEncoderInDataSz,
		ConvEncoderOutDataSz) convEncoder;
   convEncoder <- mkConvEncoder(convEncoderG1,convEncoderG2);
   return convEncoder;
endmodule

(* synthesize *)
module mkPuncturerInstance(Puncturer#(TXGlobalCtrl,PuncturerInDataSz,PuncturerOutDataSz,
				      PuncturerInBufSz,PuncturerOutBufSz));
   Bit#(PuncturerF1Sz) f1_sz = 0;
   Bit#(PuncturerF2Sz) f2_sz = 0;
   Bit#(PuncturerF3Sz) f3_sz = 0;
   Puncturer#(TXGlobalCtrl,PuncturerInDataSz,PuncturerOutDataSz,
	      PuncturerInBufSz,PuncturerOutBufSz) puncturer;
   puncturer <- mkPuncturer(puncturerMapCtrl,
			    parFunc(f1_sz,puncturerF1),
			    parFunc(f2_sz,puncturerF2),
			    parFunc(f3_sz,puncturerF3));
   return puncturer;
endmodule

module mkEncoder(Encoder#(TXGlobalCtrl,EncoderInDataSz,
			  EncoderOutDataSz));   
   // state elements
   let convEncoder <- mkConvEncoderInstance;
   let puncturer <- mkPuncturerInstance;   
   
   // connections
   mkConnection(convEncoder.out,puncturer.in);
   
   // methods
   interface in = convEncoder.in;
   interface out = puncturer.out;
endmodule





