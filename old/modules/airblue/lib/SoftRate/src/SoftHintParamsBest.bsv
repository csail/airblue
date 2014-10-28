import FixedPoint::*;
import GetPut::*;

`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_softhint_table.bsh"

typedef Bit#(16) PacketBitLength;
typedef FixedPoint#(8,0) BitErrorRate;
typedef FixedPoint#(16,48) BerFrac;

function BerFrac getBER(Bit#(8) hint, Rate rate);
   case (rate) matches
      R0: return get_ber_r0(hint);
      R1: return get_ber_r1(hint);
      R2: return get_ber_r2(hint);
      R3: return get_ber_r3(hint);
      R4: return get_ber_r4(hint);
      R5: return get_ber_r4(hint);
      R6: return get_ber_r6(hint);
      R7: return get_ber_r7(hint);
   endcase
endfunction

