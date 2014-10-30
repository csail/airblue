import Vector::*;
import FIFO::*;


// local includes
import AirblueTypes::*;
`include "asim/provides/airblue_parameters.bsh"


typedef struct {
   Rate rate;
   SoftPhyHints hint;
   Bool isLast;
} SoftHintMesg deriving (Bits);


interface SoftHintAvg;
   interface Put#(SoftHintMesg) in;
   interface Get#(BitErrorRate) out;
endinterface


module mkSoftHintAvg (SoftHintAvg);

   FIFO#(SoftHintMesg) inQ <- mkFIFO;
   FIFO#(BitErrorRate) outQ <- mkFIFO;

   Reg#(BitErrorRate) expectedBER <- mkReg(minBound);
   Reg#(Bit#(16)) bits <- mkReg(0);

   FIFO#(Tuple2#(BitErrorRate, Bit#(16))) berSumQ <- mkFIFO;

   rule update;
      let hint = inQ.first.hint;
      let rate = inQ.first.rate;
      let hintBER = getBER(hint, rate);

      let diff = expectedBER - hintBER;
      let correction = jacobianTable(abs(diff));

      // check for overflow (hintBER is always negative)
      if (diff < expectedBER)
         correction = 0;

      let ber = max(expectedBER, hintBER) + correction;

      if (inQ.first.isLast)
        begin
          expectedBER <= minBound;
          bits <= 0;

          berSumQ.enq(tuple2(ber, bits+1));
        end
      else
        begin
          expectedBER <= ber;
          bits <= bits + 1;
        end

      inQ.deq();
   endrule

   rule averageBitErrors;
      let { ber, len } = berSumQ.first;

      let pwr2 = 15 - countZerosMSB(len);
      let frac = getPacketLengthExp(len[pwr2-1:pwr2-4]);

      let berAvg = ber - (fromUInt(pwr2) + fxptSignExtend(frac));

      // check for underflow
      if (berAvg >= ber)
         berAvg = minBound;

      outQ.enq(berAvg);

      berSumQ.deq();
   endrule

   interface in = toPut(inQ);
   interface out = toGet(outQ);

endmodule
