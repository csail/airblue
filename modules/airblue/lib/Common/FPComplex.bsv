//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

//////////////////////////////////////////////////////////
// Some useful functions for FixedPoint Complex Type
// Author: Alfred Man C Ng 
// Email: mcn02@mit.edu
// Data: 9-29-2006
/////////////////////////////////////////////////////////

import Complex::*;
//import ComplexLibrary::*;
import FixedPoint::*;
//import FixedPointLibrary::*;

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
  provisos (Add#(n, xxA, TAdd#(n,xxA)),
            Bits#(FixedPoint#(ai, af), TAdd#(n, xxA)));
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

// for fixedpoint complex scale by fixed point 
function FPComplex#(ri,rf) fpcmplxScale(FixedPoint#(ai,af) a, FPComplex#(bi,bf) b)
        provisos (Add#(ai,bi,ci),  Add#(af,bf,rf), Add#(TAdd#(ai,af), TAdd#(bi,bf), TAdd#(ci,rf)), 
		  Arith#(FixedPoint#(ri,rf)), Add#(1,ci,ri), Add#(1, TAdd#(ci,rf), TAdd#(ri,rf)),
                  Literal#(FixedPoint::FixedPoint#(ai, af)));
      let scale = FPComplex{img: 0, rel: a};
      return fpcmplxMult(scale,b);
endfunction // Complex

//for fixedpoint complex signextend
function FPComplex#(ri,rf) fpcmplxSignExtend(FPComplex#(ai,af) a)
  provisos (Add#(xxA,ai,ri), Add#(fdiff,af,rf), Add#(xxC,TAdd#(ai,af),TAdd#(ri,rf)));
      return cmplx(fxptSignExtend(a.rel), fxptSignExtend(a.img));
endfunction // Complex

//for fixedpoint complex signextend
function FPComplex#(ri,rf) fpcmplxZeroExtend(FPComplex#(ai,af) a)
  provisos (Add#(xxA,ai,ri), Add#(fdiff,af,rf), Add#(xxC,TAdd#(ai,af),TAdd#(ri,rf)));
      return cmplx(fxptZeroExtend(a.rel), fxptZeroExtend(a.img));
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
      return (fxptZeroExtend(fxptMult(a.rel, a.rel)) + fxptZeroExtend(fxptMult(a.img, a.img)));
endfunction // FixedPoint

function FixedPoint#(ai,af) fpcmplxGetRel(FPComplex#(ai,af) a);
      return a.rel;
endfunction // Complex

function FPComplex#(ai,af) fpcmplxFromFxpt(FixedPoint#(ai,af) a)
       provisos(Literal#(FixedPoint::FixedPoint#(ai, af)));
      return FPComplex{rel:a,img:0};
endfunction // Complex
