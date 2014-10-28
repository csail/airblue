import GetPut::*;

`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_shift_regs.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/register_library.bsh"
`include "asim/provides/c_bus_utils.bsh"


interface FreqEstimator;

   interface Put#(Sample) in;
   interface Get#(FineTimeData) out;

   interface Put#(LongCorrelation) coarseCorrIn;
   interface Put#(LongCorrelation) fineCorrIn;

endinterface


typedef enum {
   CoarseFreq,
   FineFreq
} FreqControl deriving (Eq,Bits);


(* synthesize *)
module mkFreqEstimator(FreqEstimator);

   FIFO#(Sample) inQ <- mkFIFO;
   FIFO#(FineTimeData) outQ <- mkFIFO;

   FIFO#(LongCorrelation) coarseCorrQ <- mkFIFO;
   FIFO#(LongCorrelation) fineCorrQ <- mkFIFO;

   // current angle
   Reg#(FreqAngle) angle <- mkReg(0);

   // carrier frequency offset
   Reg#(FreqAngle) freqOffset <- mkReg(0);
   Wire#(Maybe#(Tuple2#(FreqAngle,FreqControl))) newOffset <- mkDWire(tagged Invalid);

   // control: reset on coarse estimate, adjust on fine estimation
   FIFO#(FreqControl) controlQ <- mkFIFO;
   RWire#(LongCorrelation) coarseCorrWire <- mkRWire;
   RWire#(LongCorrelation) fineCorrWire <- mkRWire;

   // CORDIC constants
   Integer cordicPipe = valueOf(CORDICPipe);
   Integer cordicIter = valueOf(CORDICIter);
   Integer cordicStep = cordicIter/cordicPipe; // how many stages perform per cycle

   // CORDIC
   ArcTan#(CorrIntPrec,SyncFractPrec,1,SyncFractPrec) cordicArcTan <-
      mkArcTan_Pipe(cordicIter,cordicStep);
   CosAndSin#(SyncIntPrec,SyncFractPrec,1,SyncFractPrec) cordicCosSin <-
      mkCosAndSin_Pipe(cordicIter,cordicStep);

   FIFO#(Bool) detectQ <- mkSizedFIFO(cordicPipe+2);//cordicPipe+1);

   (* descending_urgency = "coarseCorr, fineCorr" *)
   rule coarseCorr;
      let corr = coarseCorrQ.first;
      coarseCorrQ.deq();
      cordicArcTan.putXY(corr.rel, corr.img);
      controlQ.enq(CoarseFreq);
   endrule

   rule fineCorr;
      let corr = fineCorrQ.first;
      fineCorrQ.deq();
      cordicArcTan.putXY(corr.rel, corr.img);
      controlQ.enq(FineFreq);
   endrule

   rule estimateFreq;
      // estimate carrier frequency offset
      let offset <- cordicArcTan.getArcTan();

      let value = case (controlQ.first) matches
         CoarseFreq : return -(offset >> 4);
         FineFreq   : return freqOffset - (offset >> 6);
      endcase;

      newOffset <= tagged Valid tuple2(value, controlQ.first);

      if (`DEBUG_SYNCHRONIZER == 1)
        begin
          $write("FreqOffset: ");
          fxptWrite(7, value);
          $display("");
        end

      controlQ.deq();
   endrule

   rule computeRotation;
      // compute current rotation
      let newAngle = angle + freqOffset;
      angle <= newAngle;

      cordicCosSin.putAngle(newAngle);

      Bool detect = False;
      if (newOffset matches tagged Valid {.offset, .ctrl})
        begin
          freqOffset <= offset;
          detect = (ctrl == CoarseFreq);
        end

      detectQ.enq(detect);
   endrule

   rule rotateSample;
      let data = inQ.first;

      let pair <- cordicCosSin.getCosSinPair();
      Sample rotation = cmplx(pair.cos, pair.sin);
      Sample rotated = fpcmplxTruncate(fpcmplxMult(data, rotation));

      outQ.enq(FineTimeData {
         data: rotated,
         detect: detectQ.first
      });

      inQ.deq();
      detectQ.deq();
   endrule

   interface in = toPut(inQ);
   interface out = toGet(outQ);

   interface coarseCorrIn = toPut(coarseCorrQ);
   interface fineCorrIn = toPut(fineCorrQ);

endmodule
