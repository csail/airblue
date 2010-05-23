import GetPut::*;
import ConfigReg::*;

`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_shift_regs.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/register_library.bsh"
`include "asim/provides/c_bus_utils.bsh"


interface FreqEstimator;

   method Action estimateCoarseFreq(LongCorrelation corr);
   method Action estimateFineFreq(LongCorrelation corr);

   interface Put#(Sample) in;
   interface Get#(FineTimeData) out;

endinterface


typedef enum {
   CoarseFreq,
   FineFreq
} FreqControl deriving (Eq,Bits);

typedef FixedPoint#(2,14) FreqAngle;


import "BDPI" function FPComplex#(2,14) rotate(FPComplex#(2,14) in, Bit#(32) count, FixedPoint#(18,14) cr, FixedPoint#(18,14) ci);


(* synthesize *)
module mkFreqEstimator(FreqEstimator);

   FIFO#(Sample) inQ <- mkSizedFIFO(5);
   FIFO#(FineTimeData) outQ <- mkFIFO;

   // current angle
   Reg#(LongCorrelation) corr <-mkConfigReg(0);
   Wire#(Bool) corrChanged <- mkDWire(False);

   Reg#(Bit#(32)) count <- mkReg(0);

   rule rot;
      FPComplex#(CorrIntPrec,14) t = fpcmplxTruncate(corr);
      FPComplex#(18,14) ext = fpcmplxSignExtend(t);
      Sample rotated = rotate(inQ.first, count, ext.rel, ext.img);

      outQ.enq(FineTimeData {
         data: rotated,
         detect: corrChanged
      });

      inQ.deq();
      count <= count + 1;
   endrule

   method Action estimateCoarseFreq(LongCorrelation v);
      corr <= v;
      corrChanged <= True;
      $display("estimating coarse freq");
   endmethod

   method Action estimateFineFreq(LongCorrelation v);
      noAction;
   endmethod

   interface in = toPut(inQ);
   interface out = toGet(outQ);

endmodule
