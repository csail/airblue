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
// Some useful functions for Complex Type
// Author: Alfred Man C Ng 
// Email: mcn02@mit.edu
// Data: 9-29-2006
/////////////////////////////////////////////////////////

import Complex::*;
import FShow::*;

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
  
instance FShow#(Complex#(data))
  provisos(FShow#(data));
   function Fmt fshow (Complex#(data) comp)
     provisos(FShow#(data));
     return fshow(comp.rel) + $format(" + ") + fshow(comp.img) + $format("i");
   endfunction
endinstance
