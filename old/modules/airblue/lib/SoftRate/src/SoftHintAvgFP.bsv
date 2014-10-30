import Vector::*;
import FIFO::*;


// local includes
import AirblueTypes::*;


typedef struct {
   Vector#(n, SoftPhyHints) hints;
   Bool isNewPacket;
} SoftHintMesg#(type n) deriving (Bits);


interface SoftHintAvg#(type n);
   interface Put#(SoftHintMesg#(n)) in;
   interface Get#(AvgBitError) out;
endinterface


module mkSoftHintAvg (SoftHintAvg#(n))
      provisos (Add#(1,x,n));

   FIFO#(SoftHintMesg#(n)) inQ <- mkFIFO;
   FIFO#(AvgBitError) outQ <- mkFIFO;

   Reg#(BitErrorRate) expectedBER <- mkReg(0);
   Reg#(SoftPhyHints) minHint <- mkReg(maxBound);
   Reg#(Bit#(16)) bits <- mkReg(0);

   FIFO#(Tuple2#(BitErrorRate,Bit#(16))) berSumQ <- mkFIFO;

   rule update;
      let hints = inQ.first.hints;
      let sum = fold(\+ , map(getBER_R3, hints));

      if (inQ.first.isNewPacket)
        begin
          if (bits > 0)
             berSumQ.enq(tuple2(expectedBER,bits));
          bits <= fromInteger(valueOf(n));
          expectedBER <= sum;
          minHint <= fold(min, hints);
          $display("minHint = %d, bits = %d", minHint, bits);
        end
      else
        begin
          bits <= bits + fromInteger(valueOf(n));
          expectedBER <= sum + expectedBER;
          minHint <= min(minHint, fold(min, hints));
        end

      inQ.deq();
   endrule

   function AvgBitError toExp(BitErrorRate r);
      Vector#(48, Bit#(1)) v = reverse(unpack(pack(r)));
      AvgBitError e = minBound;
      let idxM = findElem(1, v);
      if (idxM matches tagged Valid .idx)
        begin
          Bit#(1) f = 0;
          Int#(7) i = 16 - unpack(pack(extend(idx)));


          if (idx < 32 && v[idx+1] == 1)
             f = 1;

          e = AvgBitError {i: pack(i), f: f};
        end
      return e;
   endfunction

   rule averageBitErrors;
      let { ber, len } = berSumQ.first;

      let berExp = toExp(ber);
      let berAvg = berExp - getPacketLengthExp(len);

      // check for underflow
      if (berAvg >= berExp)
         berAvg = minBound;

      Int#(7) i = fxptGetInt(berExp);
      $display("i=",i);

      outQ.enq(berAvg);

      berSumQ.deq();
   endrule

   interface in = toPut(inQ);
   interface out = toGet(outQ);

endmodule
