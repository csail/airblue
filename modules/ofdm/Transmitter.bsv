import Connectable::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_parameters::*;
import ofdm_scrambler::*;
import ofdm_encoder::*;
import ofdm_interleaver::*;
import ofdm_mapper::*;
import ofdm_pilot_insert::*;
import ofdm_ifft::*;
import ofdm_cp_insert::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;
import ofdm_preambles::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import Parameters::*;
// import Scrambler::*;
// import Encoder::*;
// import Interleaver::*;
// import Mapper::*;
// import PilotInsert::*;
// import FFTIFFT::*;
// import CPInsert::*;
// import Preambles::*;
// import LibraryFunctions::*;

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

(* synthesize *)
module [Module] mkIFFTInstance (IFFT#(TXGlobalCtrl,FFTIFFTSz,
				      TXFPIPrec,TXFPFPrec));
   IFFT#(TXGlobalCtrl,FFTIFFTSz,TXFPIPrec,TXFPFPrec) block;
   block <- mkIFFT;
   return block;
endmodule

(* synthesize *)
module mkCPInsertInstance(CPInsert#(TXGlobalCtrl,CPInsertDataSz,
				    TXFPIPrec,TXFPFPrec));
   CPInsert#(TXGlobalCtrl,CPInsertDataSz,
	     TXFPIPrec,TXFPFPrec) block;
   block <- mkCPInsert(cpInsertMapCtrl,getShortPreambles,
		       getLongPreambles);
   return block;
endmodule

(* synthesize *)
module mkTransmitterInstance
   (Transmitter#(TXScramblerAndGlobalCtrl,ScramblerDataSz,
		 TXFPIPrec,TXFPFPrec));
   // state elements
   let scrambler <- mkScramblerInstance;
   let encoder <- mkEncoderInstance;
   let interleaver <- mkInterleaverInstance;
   let mapper <- mkMapperInstance;
   let pilotInsert <- mkPilotInsertInstance;
   let ifft <- mkIFFTInstance;
   let cpInsert <- mkCPInsertInstance;
   
   // connections
   mkConnectionPrint("Scrm -> Conv",scrambler.out,encoder.in);
   mkConnectionPrint("Enco -> Intr",encoder.out,interleaver.in);
   mkConnectionPrint("Intr -> Mapr",interleaver.out,mapper.in);
   mkConnectionPrint("Mapr -> Pilt",mapper.out,pilotInsert.in);
   mkConnectionPrint("Pilt -> IFFT",pilotInsert.out,ifft.in);
   mkConnectionPrint("IFFT -> CPIn",ifft.out,cpInsert.in);
//     mkConnection(scrambler.out,encoder.in);
//     mkConnection(encoder.out,interleaver.in);
//     mkConnection(interleaver.out,mapper.in);
//     mkConnection(mapper.out,pilotInsert.in);
//     mkConnection(pilotInsert.out,ifft.in);
//     mkConnection(ifft.out,cpInsert.in);
   
   // methods
   interface in = scrambler.in;
   interface out = cpInsert.out;
endmodule
		     



