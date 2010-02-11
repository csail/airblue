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

//import EHRReg::*;
import Vector::*;

// Local includes
`include "asim/provides/airblue_common.bsh"

interface FIFOD#(numeric type sz,   // buffer size
		 numeric type i_sz, // input size
		 numeric type o_sz, // output size
		 type data_t);
      method Action enq(Vector#(i_sz, data_t) msg);
      method Vector#(o_sz, data_t) first();
      method Action deq();
      method Action clear();
      method Bool notEmpty(); // means have enough elements to deq
      method Bool notFull();  // means have enough spaces to enq
endinterface

typedef struct{
  Bit#(1)  header; 
  Bit#(sz) index; 
} FIFODIndex#(numeric type sz) deriving (Bits, Eq);

function Bit#(sz1) getUsage(Integer fifo_sz,
			    FIFODIndex#(sz) head,
			    FIFODIndex#(sz) tail)
  provisos (Add#(sz,xxA,sz1));
      let isSameHeader = head.header == tail.header;
      Bit#(sz1) fifoSz = fromInteger(fifo_sz);
      Bit#(sz1) headIdx = zeroExtend(head.index);
      Bit#(sz1) tailIdx = zeroExtend(tail.index);
      Bit#(sz1) res = isSameHeader ?
		      tailIdx - headIdx :
		      fifoSz - (headIdx - tailIdx);
      return res;
endfunction // Bool

function FIFODIndex#(sz) incrFIFODIndex(Integer fifo_sz,
					Integer incr_sz,
					FIFODIndex#(sz) fifoIdx);
      Bit#(sz) maxIdx = fromInteger(fifo_sz - incr_sz);
      Bit#(sz) incr = ((fifo_sz - incr_sz) == 0) ? 0 : 
		      fromInteger(incr_sz);
      FIFODIndex#(sz) res = (fifoIdx.index == maxIdx) ?
			    FIFODIndex{ header: ~fifoIdx.header,
					index: 0} :
			    FIFODIndex{ header: fifoIdx.header,
					index: fifoIdx.index + incr};
      return res;
endfunction // FIFODIndex

module mkFIFOD(FIFOD#(sz, i_sz, o_sz, data_t))
  provisos (Mul#(i_sz, xxA, sz),
	    Mul#(o_sz, xxB, sz),
	    Bits#(Vector#(sz,data_t), xxC),
	    Log#(sz,idx_sz),
	    Add#(sz,1,szp1),
	    Log#(szp1,usage_sz),
	    Add#(idx_sz,xxD,usage_sz));

   FIFODIndex#(idx_sz) initIdx = FIFODIndex{ header: 0,
					     index: 0};
   Reg#(Vector#(sz, data_t)) buffer <- mkRegU;
   EHRReg#(2, FIFODIndex#(idx_sz)) head <- mkEHRReg(initIdx);
   EHRReg#(2, FIFODIndex#(idx_sz)) tail <- mkEHRReg(initIdx);

   Integer fifo_sz       = valueOf(sz);
   Integer incr_head     = valueOf(o_sz);
   Integer incr_tail     = valueOf(i_sz);
   let tail0 = (tail[0]);
   let tail1 = (tail[1]);
   let head0 = (head[0]);
   let head1 = (head[1]);
   Bit#(usage_sz) usage0 = getUsage(fifo_sz, head0, tail0);
   Bit#(usage_sz) usage1 = getUsage(fifo_sz, head1, tail1);
   let canDeq = usage0 >= fromInteger(incr_head);
   let canEnq = usage1 <= fromInteger(fifo_sz - incr_tail);

   method Action enq(Vector#(i_sz, data_t) msg) if (canEnq);
      Vector#(sz,data_t) newBuffer = buffer;
      tail[1] <= incrFIFODIndex(fifo_sz, incr_tail, tail1);
      for (Integer i = 0; i < valueOf(i_sz); i = i + 1)
  	  newBuffer[tail1.index+fromInteger(i)] = msg[i];
      buffer <= newBuffer;
//      $display("enq: usage1 = %d",usage1);      
   endmethod

   method Vector#(o_sz, data_t) first() if (canDeq);
      let bufferVec = buffer;
      Vector#(o_sz, data_t) outVec = newVector;
      for (Integer i = 0; i < valueOf(o_sz); i = i + 1)
	outVec[i] = bufferVec[head0.index+fromInteger(i)];
      return outVec;
   endmethod
     
   method Action deq() if (canDeq);
      head[0] <= incrFIFODIndex(fifo_sz, incr_head, head0);
//      $display("deq: usage0 = %d",usage0);
   endmethod

   method Action clear();
      head[0] <= initIdx;
      tail[0] <= initIdx;
   endmethod
   
   method Bool notEmpty();
      return canDeq;
   endmethod
   
   // note that this can be different from canEnq
   method Bool notFull();
      return usage0 <= fromInteger(fifo_sz - incr_tail);
   endmethod

endmodule // mkDiffFIFO

(* synthesize *)
module mkTestFIFOD(Empty);

   FIFOD#(12,3,4,Bit#(1)) dFifo <- mkFIFOD;
   Reg#(Bit#(3)) counter <- mkReg(0);
   Reg#(Bit#(32) ) clockCnt <- mkReg(0);
 
   rule enqData(True);
      counter <= counter + 1;
      dFifo.enq(unpack(counter));
      $display("enq: %b",counter);
   endrule

   rule deqData(True);
      let data = dFifo.first;
      dFifo.deq;
      $display("deq: %b",pack(data));
   endrule

   rule advClock(True);
      clockCnt <= clockCnt + 1;
      $display("clock: %d",clockCnt);
      $display("notEmpty: %d",dFifo.notEmpty);
      $display("notFull: %d",dFifo.notFull);      
   endrule

endmodule // TestDiffFIFO


