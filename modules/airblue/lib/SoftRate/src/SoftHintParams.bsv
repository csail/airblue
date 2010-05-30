import FixedPoint::*;
import GetPut::*;

`include "asim/provides/airblue_parameters.bsh"

typedef FixedPoint#(16,32) BitErrorRate;
typedef FixedPoint#(7,1) AvgBitError;

function BitErrorRate getBER_log(SoftPhyHints hint, Rate rate);
   case (rate) matches
      R0: return getBER_R0_log(hint);
      R1: return getBER_R1_log(hint);
      R2: return getBER_R2_log(hint);
      R3: return getBER_R3_log(hint);
      R4: return getBER_R4_log(hint);
      R5: return getBER_R4_log(hint);
      R6: return getBER_R6_log(hint);
      R7: return getBER_R7_log(hint);
   endcase
endfunction

function AvgBitError getPacketLengthExp(Bit#(16) length);
   AvgBitError e = 14.5;
   if (length < 76)
      e = 6;
   else if (length < 108)
      e = 6.5;
   else if (length < 153)
      e = 7;
   else if (length < 216)
      e = 7.5;
   else if (length < 305)
      e = 8;
   else if (length < 431)
      e = 8.5;
   else if (length < 609)
      e = 9;
   else if (length < 862)
      e = 9.5;
   else if (length < 1218)
      e = 10;
   else if (length < 1723)
      e = 10.5;
   else if (length < 2436)
      e = 11;
   else if (length < 3445)
      e = 11.5;
   else if (length < 4871)
      e = 12;
   else if (length < 6889)
      e = 12.5;
   else if (length < 9742)
      e = 13;
   else if (length < 13778)
      e = 13.5;
   else if (length < 19484)
      e = 14;
   return e;
endfunction
