/*  Project     :   ARMO
 *  Package     :   fftifft.bsv
 *  Author(s)   :   Gopal Raghavan
 *  Comments    :   This package implements a scalable fft 
 *
 *  (c) NOKIA 2006
 */

import Connectable::*;
import Complex::*;
import FixedPoint::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;
import ofdm_fftifft_params::*;
import ofdm_fftifft_library::*;

// import ComplexLibrary::*;
// import FPComplex::*;
// import DataTypes::*;
// import CORDIC::*;
// import Pipeline2::*;
// import Controls::*;
// import Interfaces::*;
// import LibraryFunctions::*;
// import FixedPointLibrary::*;

interface FFTIFFT;
	// input
	method Action putInput(Bool isIFFT, 
			       FFTDataVec fpcmplxVec);
	// output
	method ActionValue#(FFTDataVec) getOutput();
endinterface

module [Module] mkFFTIFFT(FFTIFFT);
   FFTStage noStages = fromInteger(valueOf(LogFFTSz)-1);
   
   // state elements
   Pipeline2#(FFTTuples) pipeline <- mkPipeline2_Circ(noStages,mkOneStage); 

   FIFO#(Bool) isIFFTQ <- mkSizedFIFO(valueOf(LogFFTSz));

   function FFTData shifting(FFTData inData);
   begin
      Nat shiftSz = fromInteger(valueOf(LogFFTSz));
      return cmplx(inData.rel>>shiftSz,inData.img>>shiftSz);
   end
   endfunction
   
   // methods
   method Action putInput(Bool isIFFT, FFTDataVec fpcmplxVec);
      if (isIFFT)
	fpcmplxVec = map(cmplxSwap, fpcmplxVec);
      isIFFTQ.enq(isIFFT);
      pipeline.in.put(tuple2(0, fpcmplxVec));
   endmethod

   method ActionValue#(FFTDataVec) getOutput();
      let mesg <- pipeline.out.get;
      let outVec = fftPermuteRes(tpl_2(mesg));
      let isIFFT = isIFFTQ.first;
      if (isIFFT)
	outVec = map(cmplxSwap, map(shifting, outVec));
      isIFFTQ.deq;
      return outVec;
   endmethod
endmodule

module [Module] mkFFT(FFT#(ctrl_t,FFTSz,ISz,FSz))
   provisos (Bits#(ctrl_t,ctrl_sz));
   
   FFTIFFT fft <- mkFFTIFFT;
   FIFO#(FFTMesg#(ctrl_t,FFTSz,ISz,FSz)) inQ <- mkLFIFO;
   FIFO#(ChannelEstimatorMesg#(ctrl_t,FFTSz,ISz,FSz)) outQ; 
   outQ <- mkSizedFIFO(2);
   FIFO#(ctrl_t) ctrlQ <- mkSizedFIFO(valueOf(LogFFTSz));
   
   // rule
   rule putInput(True);
      let mesg = inQ.first;
      let ctrl = mesg.control;
      let data = map(fpcmplxSignExtend,mesg.data);
      inQ.deq;
      fft.putInput(False,data);
      ctrlQ.enq(ctrl);
   endrule
   
   rule getOutput(True);
      let data <- fft.getOutput;
      Vector#(HalfFFTSz,FFTData) fstHalfVec = take(data);
      Vector#(HalfFFTSz,FFTData) sndHalfVec = takeTail(data);
      data = append(sndHalfVec,fstHalfVec);
      let oData = map(fpcmplxTruncate,data);
      let oCtrl = ctrlQ.first;
      ctrlQ.deq;
      outQ.enq(Mesg{control:oCtrl,data:oData});
   endrule
	       
   // methods
   interface in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule
