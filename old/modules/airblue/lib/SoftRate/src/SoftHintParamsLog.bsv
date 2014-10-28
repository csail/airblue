import FixedPoint::*;
import GetPut::*;
import Real::*;

`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_softhint_table.bsh"

typedef Bit#(16) PacketBitLength;
typedef FixedPoint#(7,4) BitErrorRate;
//typedef FixedPoint#(7,4) AvgBitError;


function BitErrorRate jacobianTable(BitErrorRate diff);
    BitErrorRate res = 0.0;
    Real eps = (2.0 ** -4);
    for (Integer i = 1; i <= 16; i=i+1)
      begin
        Real x = fromInteger(i) * eps;
        Real limit = -log2(2.0 ** (x - eps / 2) - 1);
        if (diff < fromReal(limit))
           res = fromReal(x);
      end
    return res;
endfunction

//function FixedPoint#(1,4) jacobianTable0(FixedPoint#(0,4) diff);
//   FixedPoint#(1,4) res = ?;
//   for (Integer i = 0; i < 16; i=i+1)
//     begin
//       Real x = -log2(2.0 ** (fromInteger(i) / 16.0) + 1)
//       if (fxptGetFrac(diff) == fromInteger(i))
//          res = fromReal(x);
//     end
//   return res;
//endfunction

function BitErrorRate getBER_log(SoftPhyHints hint, Rate rate);
   Bit#(8) h = truncate(hint);
   case (rate) matches
      R0: return get_ber_r0_log(h);
      R1: return get_ber_r1_log(h);
      R2: return get_ber_r2_log(h);
      R3: return get_ber_r3_log(h);
      R4: return get_ber_r4_log(h);
      R5: return get_ber_r4_log(h);
      R6: return get_ber_r6_log(h);
      R7: return get_ber_r7_log(h);
   endcase
endfunction

function FixedPoint#(1,4) getPacketLengthExp(Bit#(4) lowOrderBits);
   FixedPoint#(1,4) res = ?;
   for (Integer i = 0; i < 16; i=i+1)
     begin
       Real x = log2(fromInteger(i + 16)) - 4.0;
       if (lowOrderBits == fromInteger(i))
          res = fromReal(x);
     end
   return res;
endfunction
