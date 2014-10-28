import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;

// local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"

typedef struct {
   Rate rate;
   PhyHints hints;
   Bool isLast;
} SoftHintMesg deriving (Bits);


interface SoftHintAvg;
   interface Put#(SoftHintMesg) in;
   interface Get#(BitErrorRate) out;
endinterface


typedef enum {
   Input,
   Divide,
   Multiply
} SoftHintAvgState deriving (Eq,Bits);


(* synthesize *)
module mkSoftHintAvg (SoftHintAvg);

   FIFO#(SoftHintMesg) inQ <- mkPipelineFIFO;
   FIFOF#(BitErrorRate) outQ <- mkFIFOF;

   Reg#(SoftHintAvgState) state <- mkReg(Input);

   Reg#(Bit#(16)) bits <- mkReg(0);
   Reg#(BerFrac) berReg <- mkReg(0);

   Reg#(BerFrac) berRegShift <- mkRegU;
   Reg#(Bit#(4)) frac <- mkRegU;

   function Bit#(4) getFraction(Bit#(4) f);
      FixedPoint#(2,4) res = 0;
      for (Integer i = 1; i < 16; i=i+1)
        if (f == fromInteger(i))
          begin
            res = fromReal(32.0 / (16.0 + fromInteger(i)));
          end
      return pack(fxptGetFrac(res));
   endfunction

   rule readInput (state == Input);
      let hints = inQ.first.hints;
      let rate = inQ.first.rate;

      //$write("SoftHintAvg hint: %d bits = %d ber: ", hint, bits);
      //fxptWrite(10, berReg);
      //$display("");

      Vector#(8,BerFrac) bers = newVector;
      for (Integer i = 0; i < 8; i=i+1)
         bers[i] = getBER(hints[i], rate);

      berReg <= berReg + fold(\+ , bers);
      bits <= bits + 1;

      if (inQ.first.isLast)
        begin
          state <= Divide;
        end

      inQ.deq();
      outQ.clear();
   endrule

   rule average (state == Divide);
      let hob = bits[15:5];
      let lob = bits[3:0];
      if (hob == 0)
        begin
           //$write("SoftHintAvg DIVIDE bits = %d ber: ", bits);
           //fxptWrite(10, berReg);
           //$display("");
           berRegShift <= (berReg >> 6);
           berReg <= (lob == 0 ? berReg >> 4 : berReg >> 5);
           frac <= (lob == 0 ? 0 : getFraction(bits[3:0]));
           state <= Multiply;
        end
      else
        begin
          //$write("SoftHintAvg DIVIDE bits = %d ber: ", bits);
          //fxptWrite(10, berReg);
          //$display("");
          bits <= (bits >> 1);
          berReg <= (berReg >> 1);
        end
   endrule

   rule multiply (state == Multiply);
      if (frac == 0)
        begin
          //$write("SoftHintAvg FINAL BER: ");
          //fxptWrite(10, berReg);
          let zeros = countZerosMSB(pack(fxptGetFrac(berReg)));
          //$display(" zeros = %d", zeros);
          outQ.enq(fromUInt(zeros));
          berReg <= 0;
          bits <= 0;
          state <= Input;
        end
      else
        begin
          if (msb(frac) == 1)
             berReg <= berReg + berRegShift;
          berRegShift <= (berRegShift >> 1);
          frac <= (frac << 1);
          //$write("SoftHintAvg MULTIPLY bits = %d frac=%d ber: ", bits, frac);
          //fxptWrite(10, berReg);
          //$display("");
        end
    endrule

   interface in = toPut(inQ);
   interface out = toGet(outQ);

endmodule
