//////////////////////////////////////////////////////////
// Some useful functions for Complex Type
// Author: Alfred Man C Ng 
// Email: mcn02@mit.edu
// Data: 9-29-2006
/////////////////////////////////////////////////////////

import Complex::*;

// complex conjugate
function Complex#(a) cmplxConj(Complex#(a) x) provisos (Arith#(a));
    return cmplx(x.rel, negate(x.img));
endfunction // Complex

instance Bounded#(Complex#(a)) provisos(Bounded#(a));

    function Complex#(a) minBound();
        a min = minBound;
        return cmplx(min,min);
    endfunction // Complex

    function Complex#(a) maxBound();
        a max = maxBound;
        return cmplx(max,max);
    endfunction // Complex

endinstance

// for complex single bit multiply
function Complex#(Bit#(rsz)) cmplxSignExtend(Complex#(Bit#(asz)) a)
  provisos (Add#(xxA,asz,rsz));
      let rel = signExtend(a.rel);
      let img = signExtend(a.img);
      return cmplx(rel, img);
endfunction // Complex

// for complex modulus = rel^2 + img^2, ri = 2ai + 1, rf = 2af
function Bit#(ri)  cmplxModSq(Complex#(Bit#(ai)) a)
  provisos (Add#(ai,ai,ci), Add#(1,ci,ri), Add#(xxA,ai,ri));
      return ((signExtend(a.rel) * signExtend(a.rel))  + (signExtend(a.img) * signExtend(a.img)));
endfunction // FixedPoint
  