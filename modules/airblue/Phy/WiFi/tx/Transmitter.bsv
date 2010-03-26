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

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import ProtocolParameters::*;
// import Scrambler::*;
// import Encoder::*;
// import Interleaver::*;
// import Mapper::*;
// import PilotInsert::*;
// import FFTIFFT::*;
// import CPInsert::*;
// import Preambles::*;
// import LibraryFunctions::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_scrambler.bsh"
`include "asim/provides/airblue_interleaver.bsh"
`include "asim/provides/airblue_mapper.bsh"
`include "asim/provides/airblue_pilot_insert.bsh"
`include "asim/provides/airblue_cyclic_prefix_insert.bsh"


(* synthesize *)
module mkScramblerInstance
   (Scrambler#(TXScramblerAndGlobalCtrl,TXGlobalCtrl,
	       ScramblerDataSz,ScramblerDataSz));
   Scrambler#(TXScramblerAndGlobalCtrl,TXGlobalCtrl,
	      ScramblerDataSz,ScramblerDataSz) block;
   block <- mkScrambler(scramblerMapCtrl,
			scramblerConvertCtrl,
			scramblerGenPoly);
   return block;
endmodule

(* synthesize *)
module mkEncoderInstance
   (Encoder#(TXGlobalCtrl,EncoderInDataSz,EncoderOutDataSz));
   Encoder#(TXGlobalCtrl,EncoderInDataSz,EncoderOutDataSz) block;
   block <- mkEncoder;
   return block;
endmodule

(* synthesize *)
module mkInterleaverInstance
   (Interleaver#(TXGlobalCtrl,InterleaverDataSz,
		 InterleaverDataSz,MinNcbps));
   Interleaver#(TXGlobalCtrl,InterleaverDataSz,
		InterleaverDataSz,MinNcbps) block;
   block <- mkInterleaver(modulationMapCtrl, interleaverGetIdx);
   return block;
endmodule

(* synthesize *)
module mkMapperInstance
   (Mapper#(TXGlobalCtrl,MapperInDataSz,MapperOutDataSz,
	    TXFPIPrec,TXFPFPrec)); 
   Mapper#(TXGlobalCtrl,MapperInDataSz,MapperOutDataSz,
	   TXFPIPrec,TXFPFPrec) block;
   block <- mkMapper(modulationMapCtrl, mapperNegateInput);
   return block;
endmodule

(* synthesize *)
module mkPilotInsertInstance
   (PilotInsert#(TXGlobalCtrl,PilotInDataSz,PilotOutDataSz,
		 TXFPIPrec,TXFPFPrec)); 
   PilotInsert#(TXGlobalCtrl,PilotInDataSz,PilotOutDataSz,
		TXFPIPrec,TXFPFPrec) block; 
   block <- mkPilotInsert(pilotMapCtrl, pilotAdder,
			  pilotPRBSMask, pilotInitSeq);
   return block;
endmodule

//(* synthesize *)
//module [Module] mkIFFTInstance (IFFT#(TXGlobalCtrl,FFTIFFTSz,
//				      TXFPIPrec,TXFPFPrec));
//   IFFT#(TXGlobalCtrl,FFTIFFTSz,TXFPIPrec,TXFPFPrec) block;
//   block <- mkIFFT;
//   return block;
//endmodule

(* synthesize *)
module mkCPInsertInstance(CPInsert#(TXGlobalCtrl,CPInsertDataSz,
				    TXFPIPrec,TXFPFPrec));
   CPInsert#(TXGlobalCtrl,CPInsertDataSz,
	     TXFPIPrec,TXFPFPrec) block;
   block <- mkCPInsert(cpInsertMapCtrl,getShortPreambles,
		       getLongPreambles);
   return block;
endmodule


module mkTransmitterInstance#(
   IFFT#(TXGlobalCtrl,FFTIFFTSz,TXFPIPrec,TXFPFPrec) ifft)
   (Transmitter#(TXScramblerAndGlobalCtrl,ScramblerDataSz,
		 TXFPIPrec,TXFPFPrec));
   // state elements
   let scrambler <- mkScramblerInstance;
   let encoder <- mkEncoderInstance;
   let interleaver <- mkInterleaverInstance;
   let mapper <- mkMapperInstance;
   let pilotInsert <- mkPilotInsertInstance;
   let cpInsert <- mkCPInsertInstance;
   
   // connections
   if(`DEBUG_TXCTRL == 1)
      begin
         mkConnectionPrint("Scrm -> Conv",scrambler.out,encoder.in);
         mkConnectionPrint("Enco -> Intr",encoder.out,interleaver.in);
         mkConnectionPrint("Intr -> Mapr",interleaver.out,mapper.in);
         mkConnectionPrint("Mapr -> Pilt",mapper.out,pilotInsert.in);
         mkConnectionPrint("Pilt -> IFFT",pilotInsert.out,ifft.in);
         mkConnectionPrint("IFFT -> CPIn",ifft.out,cpInsert.in);
      end
   else
      begin
         mkConnection(scrambler.out,encoder.in);
         mkConnection(encoder.out,interleaver.in);
         mkConnection(interleaver.out,mapper.in);
         mkConnection(mapper.out,pilotInsert.in);
         mkConnection(pilotInsert.out,ifft.in);
         mkConnection(ifft.out,cpInsert.in);
      end
   
   // methods
   interface in = scrambler.in;
   interface out = cpInsert.out;
endmodule
		     



