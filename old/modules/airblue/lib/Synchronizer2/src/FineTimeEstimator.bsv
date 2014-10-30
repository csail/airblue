import GetPut::*;
import Vector::*;

`include "asim/provides/airblue_parameters.bsh"
import AirblueCommon::*;
`include "asim/provides/airblue_shift_regs.bsh"
import AirblueTypes::*;
`include "asim/provides/register_library.bsh"
`include "asim/provides/c_bus_utils.bsh"


interface FineTimeEstimator;

   interface Put#(FineTimeData) in;
   interface Get#(PacketSync) out;

endinterface


typedef struct {
  Bool autoCorrThreshold;
  LongCorrelation autoCorrelation;
} FineTimeCorrelation deriving (Eq,Bits);


interface FineTimeAutoCorrelator;

   interface Put#(Sample) in;
   interface Get#(FineTimeCorrelation) out;

endinterface


module mkFineTimeAutoCorrelator (FineTimeAutoCorrelator);

   // auto correlation over 16 samples with 64 sample lag
   AutoCorrelator#(64, 16) autoCorrelator16 <- mkAutoCorrelator;

   // auto correlation over 64 samples with 64 sample lag
   AutoCorrelator#(64, 64) autoCorrelator64 <- mkAutoCorrelator;

   // 16-sample auto correlation reaches threshold for past 32 samples
   Accumulator#(32, Bit#(1), Bit#(6)) autoThreshold <- mkAccumulator(zeroExtend);

   // delay threshold criteria by 32 samples
   ShiftRegs#(32, Bool) threshold32 <- mkCirShiftRegsNoGetVec;

   FIFO#(FineTimeCorrelation) outQ <- mkFIFO;

   rule threshold;
      // auto correlation meets threshold
      let corr16 <- autoCorrelator16.out.get();
      let power = corr16.power;
      Correlation corr = fpcmplxTruncate(corr16.corr);

      // (|correlation|^2 / power^2) > 0.125
      let corrSq = fpcmplxModSq(corr);
      let powerSq = fxptMult(power, power);
      Bool threshold = (corrSq > (fxptZeroExtend(powerSq) >> 3));

      let count <- autoThreshold.update(threshold ? 1 : 0);
      threshold32.enq(count >= 25);

      let corr64 <- autoCorrelator64.out.get();

      outQ.enq(FineTimeCorrelation {
         autoCorrThreshold: threshold32.first,
         autoCorrelation: corr64.corr
      });
   endrule

   interface Put in;
      method Action put(Sample value);
         autoCorrelator16.in.put(value);
         autoCorrelator64.in.put(value);
      endmethod
   endinterface

   interface Get out = toGet(outQ);

endmodule


interface FineTimeCrossCorrelator;
   method Action clear;
   interface Put#(Sample) in;
   interface Get#(Bool) out;
endinterface

typedef Complex#(Bit#(1)) Sign;

module mkFineTimeCrossCorrelator (FineTimeCrossCorrelator);

   FIFO#(Sign) inQ <- mkFIFO;
   FIFO#(Bool) outQ <- mkFIFO;

   // previous 63 samples received
   ShiftRegs#(63, Sign) delay63 <- mkShiftRegs;

   // Peak detector
   PeakDetector peakDetector <- mkPeakDetector;


   function Bit#(10) signAbs(Bit#(9) x);
      Int#(9) v = unpack(pack(x));
      return extend(pack(abs(v)));
   endfunction

   function Bit#(10) estimate(Complex#(Bit#(9)) corr);
      Bit#(10) r = signAbs(corr.rel);
      Bit#(10) i = signAbs(corr.img);

      let a = max(r, i);
      let b = (r + i) / 4 * 3;

      return max(a, b);
   endfunction

   rule crossCorrelate;
      Vector#(64, Sign) lts = map(toSingleBitCmplx, take(getLongPreambles));
      Vector#(64, Sign) data = append(delay63.getVector, replicate(inQ.first));
      
      // compute cross correlation
      let value = estimate(singleBitCrossCorrelation(data, lts));

      Bool detect = False;

      let peaks = peakDetector.peaks;
      let index = peakDetector.index;
      peakDetector.update(value);

      if (peaks[0].idx == index - 64 && value > peaks[1].value)
        begin
          // trigger
          Bit#(16) product = extend(value) * extend(peaks[0].value);
          detect = product > 3000;
        end

      outQ.enq(detect);
      
      delay63.enq(inQ.first);
      inQ.deq();
   endrule

   method Action clear;
      peakDetector.clear();
   endmethod

   interface Put in;
      method Action put(Sample x);
         inQ.enq(toSingleBitCmplx(x));
      endmethod
   endinterface

   interface out = toGet(outQ);

endmodule


(* synthesize *)
module mkFineTimeEstimator (FineTimeEstimator);

   FIFO#(FineTimeData) inQ <- mkFIFO;//kSizedFIFOF(50);
   FIFO#(PacketSync) outQ <- mkFIFO;

   let autoCorrelator <- mkFineTimeAutoCorrelator;
   let crossCorrelator <- mkFineTimeCrossCorrelator;

   FIFOF#(Sample) sampleQ <- mkSizedFIFOF(3);

   Reg#(Bool) enabled <- mkReg(False);
   Reg#(Bit#(9)) counter <- mkReg(?);

   rule estimate;
      let autoCorr <- autoCorrelator.out.get();
      let crossCorrDetect <- crossCorrelator.out.get();

      FineTimeCtrl ctrl = None;
      if (enabled)
         if (autoCorr.autoCorrThreshold && crossCorrDetect)
           begin
             ctrl = Sync;
             enabled <= False;
           end
         else if (counter > 320)
           begin
             ctrl = TimeOut;
             enabled <= False;
           end

      outQ.enq(PacketSync {
         sample: sampleQ.first,
         ctrl: ctrl,
         corr: autoCorr.autoCorrelation
      });

      counter <= counter + 1;
      sampleQ.deq();
   endrule

   rule doInStuff;
       let x = inQ.first;
       inQ.deq();

       if (x.detect)
         begin
           enabled <= True;
           crossCorrelator.clear();
           counter <= 0;
         end

       let sample = x.data;

       autoCorrelator.in.put(sample);
       crossCorrelator.in.put(sample);
       sampleQ.enq(sample);
   endrule
  

   interface Put in = toPut(inQ);
   interface Get out = toGet(outQ);

endmodule
