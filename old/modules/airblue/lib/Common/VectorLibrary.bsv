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

import Vector::*;

function Vector#(psz, a) shrinkVec (Vector#(sz, a) inVec,
				    Bit#(idx_sz) sel)
  provisos (Bits#(a, asz),
	    Add#(pszM1,1,psz), 
	    Add#(pszM1,sz,nsz),
	    Div#(nsz,psz,noStages),
	    Log#(noStages,idx_sz),
	    Mul#(noStages,psz,total_sz),
	    Add#(sz,ext_sz,total_sz),
	    Bits#(Vector#(total_sz,a),xxA),
	    Bits#(Vector#(noStages,Vector#(psz,a)),xxA));
      
      Vector#(ext_sz, a) extVec = newVector;
      Vector#(total_sz, a) appendVec = append(inVec, extVec);
      Vector#(noStages, Vector#(psz, a)) outVecs = unpack(pack(appendVec));
      return outVecs[sel];
      
endfunction


function Vector#(sz, a) expandVec (Vector#(sz,a) inVec1,
				   Vector#(psz, a) inVec2,
				   Bit#(idx_sz) sel)
  provisos (Bits#(a, asz),
	    Add#(pszM1,1,psz), 
	    Add#(pszM1,sz,nsz),
	    Div#(nsz,psz,noStages),
	    Log#(noStages,idx_sz),
	    Mul#(noStages,psz,total_sz),
	    Add#(sz,ext_sz,total_sz),
	    Bits#(Vector#(total_sz,a),xxA),
	    Bits#(Vector#(noStages,Vector#(psz,a)),xxA));
      
      Vector#(ext_sz, a) extVec = newVector;
      Vector#(total_sz, a) appendVec = append(inVec1, extVec);
      Vector#(noStages, Vector#(psz, a)) outVecs = unpack(pack(appendVec));
      outVecs[sel] = inVec2;
      appendVec = unpack(pack(outVecs));
      return take(appendVec); // drop tails
      
endfunction

// pack 2D vector into 1D vector in row major order
function Vector#(o_sz,a) packVec(Vector#(r_sz,Vector#(c_sz,a)) inVec)
   provisos (Mul#(r_sz,c_sz,o_sz));
   Integer rSz = valueOf(r_sz);
   Integer cSz = valueOf(c_sz);
   Integer k = 0;
   Vector#(o_sz,a) outVec = newVector;
   for(Integer i = 0; i < rSz; i = i + 1)
      for(Integer j = 0; j < cSz; j = j + 1)
	 begin
	    outVec[k] = inVec[i][j];
	    k = k + 1;
	 end
   return outVec;
endfunction

// unpack 1D vector to 2D vector assuming 1D vector is row major
function Vector#(r_sz,Vector#(c_sz,a)) unpackVec(Vector#(i_sz,a) inVec)
   provisos (Mul#(r_sz,c_sz,i_sz));
   Integer rSz = valueOf(r_sz);
   Integer cSz = valueOf(c_sz);
   Integer k = 0;
   Vector#(r_sz,Vector#(c_sz,a)) outVec = newVector;
   Vector#(c_sz,a) tempVec = newVector;
   for(Integer i = 0; i < rSz; i = i + 1)
      begin
	 for(Integer j = 0; j < cSz; j = j + 1)
	    begin
	       tempVec[j] = inVec[k];
	       k = k + 1;
	    end
	 outVec[i] = tempVec;
      end
   return outVec;
endfunction

   









