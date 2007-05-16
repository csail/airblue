import Controls::*;
import DataTypes::*;
import Interfaces::*;
import Parameters::*;
import Synchronizer::*;
import Unserializer::*;
import FFTIFFT::*;
import ChannelEstimator::*;
import Demapper::*;
import Interleaver::*;
import Decoder::*;
import Scrambler::*;
import Connectable::*;
import GetPut::*;
import LibraryFunctions::*;

(* synthesize *)
module mkSynchronizerInstance
   (Synchronizer#(SyncIntPrec,SyncFractPrec));
   Synchronizer#(SyncIntPrec,SyncFractPrec) block <- mkSynchronizer;
   return block;
endmodule

(* synthesize *)
module mkUnserializerInstance
   (Unserializer#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec));
   Unserializer#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec) block <- mkUnserializer;
   return block;
endmodule

(* synthesize *)
module mkReceiverPreFFTInstance
   (ReceiverPreFFT#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec));
   
   // state elements
   let synchronizer <- mkSynchronizerInstance;
   let unserializer <- mkUnserializerInstance;
   
   // connections
   mkConnectionPrint("Sync -> Unse",synchronizer.out,unserializer.in);
//     mkConnection(synchroinzer.out,unserializer.in);
   
   // methods
   interface in = synchronizer.in;
   interface out = unserializer.out;
endmodule		     

(* synthesize *)
module [Module] mkFFTInstance
   (FFT#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec));
   FFT#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec) block <- mkFFT;
   return block;
endmodule

(* synthesize *)
module mkChannelEstimatorInstance
   (ChannelEstimator#(RXGlobalCtrl,CEstInDataSz,
		      CEstOutDataSz,RXFPIPrec,RXFPFPrec));
   ChannelEstimator#(RXGlobalCtrl,CEstInDataSz,
		     CEstOutDataSz,RXFPIPrec,RXFPFPrec) block;
   block <- mkChannelEstimator(pilotRemover);
   return block;
endmodule

(* synthesize *)
module mkDemapperInstance
   (Demapper#(RXGlobalCtrl,DemapperInDataSz,DemapperOutDataSz,
	      RXFPIPrec,RXFPFPrec,ViterbiMetric));
   Demapper#(RXGlobalCtrl,DemapperInDataSz,DemapperOutDataSz,
	     RXFPIPrec,RXFPFPrec,ViterbiMetric) block;
   block <- mkDemapper(modulationMapCtrl,demapperNegateOutput);
   return block;
endmodule

(* synthesize *)
module mkDeinterleaverInstance
   (Deinterleaver#(RXGlobalCtrl,DeinterleaverDataSz,
		   DeinterleaverDataSz,ViterbiMetric,MinNcbps));
   Deinterleaver#(RXGlobalCtrl,DeinterleaverDataSz,
		  DeinterleaverDataSz, ViterbiMetric,MinNcbps) block;
   block <- mkDeinterleaver(modulationMapCtrl,deinterleaverGetIndex);
   return block;
endmodule

(* synthesize *)
module mkDecoderInstance
   (Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
	     DecoderOutDataSz,Bit#(1)));
   Decoder#(RXGlobalCtrl,DecoderInDataSz,ViterbiMetric,
	    DecoderOutDataSz,Bit#(1)) block;
   block <- mkDecoder;
   return block;
endmodule
    
(* synthesize *)
module mkReceiverPreDescramblerInstance
   (ReceiverPreDescrambler#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,
			    RXFPFPrec,DecoderOutDataSz,Bit#(1)));
    // state elements
    let fft <- mkFFTInstance;
    let channelEstimator <- mkChannelEstimatorInstance;
    let demapper <- mkDemapperInstance;
    let deinterleaver <- mkDeinterleaverInstance;
    let decoder <- mkDecoderInstance;
    
    // connections
    mkConnectionPrint("FFT  -> CEst",fft.out,channelEstimator.in);
    mkConnectionPrint("CEst -> Dmap",channelEstimator.out,demapper.in);
    mkConnectionPrint("Dmap -> Dint",demapper.out,deinterleaver.in);
    mkConnectionPrint("Dint -> Deco",deinterleaver.out,decoder.in);
    //     mkConnection(synchroinzer.out,unserializer.in);
    
    // methods
    interface in = fft.in;
    interface out = decoder.out;
endmodule

(* synthesize *)
module mkDescramblerInstance
   (Descrambler#(RXDescramblerAndGlobalCtrl,
		 DescramblerDataSz,DescramblerDataSz));
   Descrambler#(RXDescramblerAndGlobalCtrl,
		DescramblerDataSz,DescramblerDataSz) block;
   block <- mkScrambler(descramblerMapCtrl,
			descramblerConvertCtrl,
			descramblerGenPoly);
   return block;
endmodule


