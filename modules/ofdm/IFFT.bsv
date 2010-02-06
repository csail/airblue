import FIFO::*;
import GetPut::*;
import Vector::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;
import ofdm_fftifft_params::*;
import ofdm_fftifft_library::*;
import ofdm_fft::*;

module [CONNECTED_MODULE] mkIFFT(IFFT#(ctrl_t,FFTSz,ISz,FSz))
   provisos (Bits#(ctrl_t,ctrl_sz));
   
   FFTIFFT ifft <- mkFFTIFFT;
   FIFO#(IFFTMesg#(ctrl_t,FFTSz,ISz,FSz)) inQ <- mkLFIFO;
   FIFO#(CPInsertMesg#(ctrl_t,FFTSz,ISz,FSz)) outQ <- mkSizedFIFO(2);
   FIFO#(ctrl_t) ctrlQ <- mkSizedFIFO(valueOf(LogFFTSz));
   
   // rule
   rule putInput(True);
      let mesg = inQ.first;
      let ctrl = mesg.control;
      let data = map(fpcmplxSignExtend,mesg.data);
      Vector#(HalfFFTSz,FFTData) fstHalfVec = take(data);
      Vector#(HalfFFTSz,FFTData) sndHalfVec = takeTail(data);
      data = append(sndHalfVec,fstHalfVec);
      inQ.deq;
      ifft.putInput(True,data);
      ctrlQ.enq(ctrl);
   endrule
   
   rule getOutput(True);
      let data <- ifft.getOutput;
      let oData = map(fpcmplxTruncate,data);
      let oCtrl = ctrlQ.first;
      ctrlQ.deq;
      outQ.enq(Mesg{control:oCtrl,data:oData});
   endrule
	       
   // methods
   interface in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule

