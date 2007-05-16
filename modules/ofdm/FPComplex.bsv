//////////////////////////////////////////////////////////
// Some useful functions for FixedPoint Complex Type
// Author: Alfred Man C Ng 
// Email: mcn02@mit.edu
// Data: 9-29-2006
/////////////////////////////////////////////////////////

import Complex::*;
import ComplexLibrary::*;
import FixedPoint::*;
import FixedPointLibrary::*;


typedef Complex#(FixedPoint#(i,f)) FPComplex#(type i, type f);

// for displaying FPComplex
function Action fpcmplxWrite(Integer fwidth, FPComplex#(i,f) a)
  provisos(Add#(1,xxA,i),
	   Add#(4,xxB,TAdd#(32,f)),
	   Add#(i,f,TAdd#(i,f)));
      return cmplxWrite(" "," + ","i",fxptWrite(fwidth),a);
endfunction // Action

//
function Complex#(Bit#(n)) fpcmplxGetMSBs(FPComplex#(ai,af) x)
  provisos (Add#(xxA, n, TAdd#(ai,af)));
      return cmplxMap(fxptGetMSBs,x);
endfunction // Complex

// for fixedpoint complex multiplication 
function FPComplex#(ri,rf) fpcmplxMult(FPComplex#(ai,af) a, FPComplex#(bi,bf) b)
        provisos (Add#(ai,bi,ci),  Add#(af,bf,rf), Add#(TAdd#(ai,af), TAdd#(bi,bf), TAdd#(ci,rf)), 
		  Arith#(FixedPoint#(ri,rf)), Add#(1,ci,ri), Add#(1, TAdd#(ci,rf), TAdd#(ri,rf)));
      let rel = fxptSignExtend(fxptMult(a.rel, b.rel)) - fxptSignExtend(fxptMult(a.img, b.img));
      let img = fxptSignExtend(fxptMult(a.rel, b.img)) + fxptSignExtend(fxptMult(a.img, b.rel));
      return cmplx(rel, img);
endfunction // Complex

//for fixedpoint complex signextend
function FPComplex#(ri,rf) fpcmplxSignExtend(FPComplex#(ai,af) a)
  provisos (Add#(xxA,ai,ri), Add#(fdiff,af,rf), Add#(xxC,TAdd#(ai,af),TAdd#(ri,rf)));
      return cmplx(fxptSignExtend(a.rel), fxptSignExtend(a.img));
endfunction // Complex

//for fixedpoint complex truncate
function FPComplex#(ri,rf) fpcmplxTruncate(FPComplex#(ai,af) a)
  provisos (Add#(xxA,ri,ai), Add#(xxB,rf,af), Add#(xxC,TAdd#(ri,rf),TAdd#(ai,af)));
      return cmplx(fxptTruncate(a.rel), fxptTruncate(a.img));
endfunction // Complex

// for fixedpoint complex modulus = rel^2 + img^2, ri = 2ai + 1, rf = 2af
function FixedPoint#(ri,rf)  fpcmplxModSq(FPComplex#(ai,af) a)
  provisos (Add#(ai,ai,ci), Add#(af,af,rf), Add#(TAdd#(ai,af), TAdd#(ai,af), TAdd#(ci,rf)),
	    Arith#(FixedPoint#(ri,rf)), Add#(1,ci,ri), Add#(1, TAdd#(ci,rf), TAdd#(ri,rf)));
      return (fxptSignExtend(fxptMult(a.rel, a.rel)) + fxptSignExtend(fxptMult(a.img, a.img)));
endfunction // FixedPoint


