import GetPut::*;

//
// Detects the 802.11a preamble using the short training sequence.
//
interface PacketDetector;

   method Action restart();

   interface Put#(Sample) in;
   interface Get#(PacketDetect) out;

endinterface


typedef enum {
   Detect,
   Collect,
   Idle
} State deriving (Eq,Bits);


(* synthesize *)
module mkPacketDetector (PacketDetector);

   FIFO#(Sample) sampleQ <- mkFIFO;
   FIFO#(PacketDetect) outQ <- mkFIFO;

   // auto correlation over 16 samples with 16 sample lag
   AutoCorrelator#(16, 16) autoCorrelator <- mkAutoCorrelator;

   // auto-correlation reaches threshold for past 32 samples
   Accumulator#(32, Bit#(1), Bit#(6)) autoThresh <- mkAccumulator(zeroExtend);

   Reg#(LongCorrelation) corrAccum <- mkRegU;
   Reg#(Bit#(4)) corrIdx <- mkRegU;
   Reg#(Bit#(2)) corrCount <- mkRegU;

   Reg#(State) state <- mkReg(Detect);

   rule detect;
      let autoCorr <- autoCorrelator.out.get();
      let power = autoCorr.power;
      let corr = autoCorr.corr;

      // (|correlation|^2 / power^2) > 0.25
      Correlation corr_trunc = fpcmplxTruncate(corr);
      let corrSq = fpcmplxModSq(corr_trunc);
      let powerSq = fxptMult(power, power);
      Bool threshold = (corrSq > (fxptZeroExtend(powerSq) >> 2));

      let count <- autoThresh.update(threshold ? 1 : 0);

      // satifies condition for 28 out of 32 samples
      if (count >= 28 && state == Detect)
        begin
          state <= Collect;
          corrIdx <= 15;
          corrCount <= 1;
          corrAccum <= corr;
        end

      Bool detect = False;

      if (state == Collect)
        begin
          if (corrIdx == 0)
            begin
              corrAccum <= corrAccum + corr;
              corrCount <= corrCount + 1;
            end

          if (corrCount == 0)
            begin
              detect = True;
              state <= Idle;
            end

          corrIdx <= corrIdx - 1;
        end

      outQ.enq(PacketDetect {
         sample: sampleQ.first,
         detect: detect,
         corr: corrAccum
      });

      sampleQ.deq();
   endrule

   method Action restart();
      state <= Detect;
   endmethod

   interface Put in;
      method Action put(Sample x);
         autoCorrelator.in.put(x);
         sampleQ.enq(x);
      endmethod
   endinterface

   interface out = toGet(outQ);

endmodule
