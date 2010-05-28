import Vector::*;
import FIFO::*;


// local includes
`include "asim/provides/fpga_components.bsh"

`include "asim/provides/airblue_types.bsh"
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

   Reg#(Bool) ready <- mkReg(True);

   Reg#(Bit#(16)) bits <- mkReg(0);

   LUTRAM#(Bit#(6),Maybe#(BitErrorRate)) berTable <- mkLUTRAM(tagged Invalid);
   Reg#(Maybe#(BitErrorRate)) nextBer <- mkReg(tagged Invalid);
   Reg#(Int#(6)) maxIdx <- mkReg(minBound);

   Reg#(Int#(6)) curIdx <- mkRegU;
   Reg#(BitErrorRate) totalBer <- mkRegU;

   FIFO#(Tuple2#(BitErrorRate,Bit#(16))) berSumQ <- mkFIFO;

   function Int#(6) idx(BitErrorRate r);
      Int#(7) i = fxptGetInt(r);
      return truncate(i >> 1);
   endfunction

   function BitErrorRate addExp(BitErrorRate a, BitErrorRate b);
      return max(a, b) + jacobianTable(abs(a - b));
   endfunction

   rule updateTable (nextBer matches tagged Valid .ber);
      let i = idx(ber);

      let sum = case (berTable.sub(pack(i))) matches
                   tagged Valid .ber2 : return addExp(ber, ber2);
                   tagged Invalid     : return ber;
                endcase;
      
      if (idx(sum) == i)
        begin
          maxIdx <= max(maxIdx, i);
          berTable.upd(pack(i), tagged Valid sum);
          nextBer <= tagged Invalid;
        end
      else
        begin
          berTable.upd(pack(i), tagged Invalid);
          nextBer <= tagged Valid sum;
        end
   endrule

   rule readInput (nextBer matches tagged Invalid &&& ready);
      let hint = inQ.first.hint;
      let rate = inQ.first.rate;

      nextBer <= tagged Valid getBER(hint, rate);
      bits <= bits + 1;

      if (inQ.first.isLast)
        begin
          curIdx <= maxIdx;
          ready <= False;
        end

      inQ.deq();
   endrule

   rule collectOutput(nextBer matches tagged Invalid &&& !ready);
      Int#(7) diff = extend(maxIdx) - extend(curIdx);

      if (berTable.sub(pack(curIdx)) matches tagged Valid .ber)
        begin
          if (diff == 0)
             totalBer <= ber;
          else if (diff <= 3)
             totalBer <= addExp(totalBer, ber);
        end

      berTable.upd(pack(curIdx), tagged Invalid);

      if (curIdx == minBound)
        begin
          maxIdx <= minBound;
          ready <= True;
          bits <= 0;
          berSumQ.enq(tuple2(totalBer, bits));
        end

      curIdx <= curIdx - 1;
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
