//////////////////////////////////////////////////////////
// Some useful functions for FixedPoint Type
// Author: Alfred Man C Ng 
// Email: mcn02@mit.edu
// Data: 9-29-2006
/////////////////////////////////////////////////////////

import FixedPoint::*;

// take the most significant n bits from the fixedpoint value, result represented in bits
function Bit#(n) fxptGetMSBs(FixedPoint#(ai,af) x)
  provisos (Add#(n, xxA, TAdd#(ai,af)));
      return tpl_1(split(pack(x)));
endfunction // Bit
























