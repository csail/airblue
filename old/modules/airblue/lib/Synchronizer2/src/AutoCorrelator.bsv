import GetPut::*;


typedef struct {
   LongCorrelation corr;
   MagnitudeSum power;
} AutoCorrelation deriving (Eq, Bits);


interface AutoCorrelator#(numeric type lag, numeric type length);
   interface Put#(Sample) in;
   interface Get#(AutoCorrelation) out;
endinterface


module mkAutoCorrelator (AutoCorrelator#(lag, length));

   // delay queue of samples
   ShiftRegs#(lag, Sample) delay <- mkCirShiftRegsNoGetVec;

   // accumulate power of last 16 samples
   Accumulator#(16, Magnitude, MagnitudeSum) powerAccum <-
      mkAccumulator(fxptZeroExtend);

   // auto correlation over length samples with given lag
   Accumulator#(length, Product, LongCorrelation) autoCorrelation <-
      mkAccumulator(fpcmplxSignExtend);

   FIFO#(AutoCorrelation) outQ <- mkFIFO;

   interface Put in;
      method Action put(Sample value);
         delay.enq(value);

         // compute power over 16 samples
         Magnitude mag = fxptTruncate(fpcmplxModSq(value));
         let power <- powerAccum.update(mag);

         // compute auto-correlation over 16 samples with given lag
         Product prod = fpcmplxTruncate(
            fpcmplxMult(cmplxConj(delay.first), value));

         let corr <- autoCorrelation.update(prod);

         outQ.enq(AutoCorrelation {
            corr: corr,
            power: power
         });
      endmethod
   endinterface

   interface Get out = toGet(outQ);

endmodule
