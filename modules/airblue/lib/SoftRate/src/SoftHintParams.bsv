import FixedPoint::*;
import GetPut::*;

`include "asim/provides/airblue_parameters.bsh"

typedef FixedPoint#(16,32) BitErrorRate;
typedef FixedPoint#(7,1) AvgBitError;

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

function BitErrorRate getBER_R0(SoftPhyHints hint);
   return 0;
endfunction

function BitErrorRate getBER_R1(SoftPhyHints hint);
   return 0;
endfunction

function BitErrorRate getBER_R2(SoftPhyHints hint);
   return 0;
endfunction

function BitErrorRate getBER_R3(SoftPhyHints hint);
   case (hint) matches
       0: return 0.497025147420472;
       1: return 0.377249161329674;
       2: return 0.380956991069051;
       3: return 0.222886421861657;
       4: return 0.257570285587287;
       5: return 0.0964556962025316;
       6: return 0.150850910650552;
       7: return 0.0553333333333333;
       8: return 0.0718052057094878;
       9: return 0.0205754432920709;
      10: return 0.0266079503273267;
      11: return 0.00639658848614072;
      12: return 0.00972036234738086;
      13: return 0.000238777459407832;
      14: return 0.0033793732033934;
      15: return 0.000117000117000117;
      16: return 0.000493577473605644;
      17: return 0;
      18: return 0.000240009600384015;
      19: return 0;
      20: return 0.00000816579837010665;
      default: return 0;
   endcase
endfunction

function BitErrorRate getBER_R4(SoftPhyHints hint);
   return 0;
endfunction

function BitErrorRate getBER_R5(SoftPhyHints hint);
   return 0;
endfunction

function BitErrorRate getBER_R6(SoftPhyHints hint);
   return 0;
endfunction

function BitErrorRate getBER_R7(SoftPhyHints hint);
   return 0;
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
