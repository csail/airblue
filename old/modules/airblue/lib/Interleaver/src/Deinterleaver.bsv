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

import FIFO::*;
import GetPut::*;
import Vector::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
`include "asim/provides/airblue_interleaver.bsh"

module mkDeinterleaver#(function Modulation mapCtrl(ctrl_t ctrl),
			function Integer getIdx(Modulation m, 
						Integer k))
   (Deinterleaver#(ctrl_t,n,n,decode_t,minNcbps))
   provisos(Mul#(6,minNcbps,maxNcbps),
	    Mul#(cntr_n,n,maxNcbps),
	    Log#(cntr_n,cntr_sz),
	    Bits#(ctrl_t,ctrl_sz),
	    Bits#(decode_t,decode_sz),
	    Bits#(Vector#(maxNcbps,decode_t),total_sz),
	    Bits#(Vector#(cntr_n,Vector#(n,decode_t)),total_sz));
      
   InterleaveBlock#(ctrl_t,n,n,decode_t,minNcbps) block;
   block <- mkInterleaveBlock(mapCtrl,getIdx);
   return block;
endmodule
