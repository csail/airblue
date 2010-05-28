import FixedPoint::*;
import GetPut::*;
import Real::*;

`include "asim/provides/airblue_parameters.bsh"

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

function BitErrorRate getBER(SoftPhyHints hint, Rate rate);
   case (rate) matches
      R0: return getBER_R0(hint);
      R1: return getBER_R1(hint);
      R2: return getBER_R2(hint);
      R3: return getBER_R3(hint);
      R4: return getBER_R4(hint);
      R5: return getBER_R4(hint);
      R6: return getBER_R6(hint);
      R7: return getBER_R7(hint);
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
