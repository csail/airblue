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

interface ShiftRegs#(numeric type size, type data_t);
  method Action enq(data_t x);              // put the element at the last position of the queue 
  method data_t first();                    // get the first element of the queue
  method Action clear();                    // clear all elements in the queue
  method Vector#(size, data_t) getVector(); // return a snapshot of the queue
endinterface

// shift reg approach 
module mkShiftRegs (ShiftRegs#(size,data_t))
  provisos (Bits#(data_t,data_w));

   // states
   Vector#(size, Reg#(data_t)) vRegs <- Vector::replicateM(mkReg(unpack(0)));

   // constants
   let maxIndex = valueOf(size) - 1;

   method Action enq(x);
   begin
      (vRegs[maxIndex])._write(x);
      for (Integer i = 0; i < maxIndex; i = i + 1)
	(vRegs[fromInteger(i)])._write((vRegs[fromInteger(i)+1])._read);
   end
   endmethod
     
   method data_t first();
   begin
      return (vRegs[0])._read;
   end
   endmethod
   
   method Action clear();
   begin
      for (Integer i = 0; i <= maxIndex; i = i + 1)
	(vRegs[fromInteger(i)])._write(unpack(0));
   end
   endmethod

   method Vector#(size, data_t) getVector();
   begin
      Vector#(size, data_t) resultV = newVector();
      for (Integer i = 0; i <= maxIndex; i = i + 1)
	resultV[fromInteger(i)] = (vRegs[fromInteger(i)])._read(); // oldest element come first
      return resultV;
   end
   endmethod
      
endmodule // mkDelay

// circular pointer approach, note that getVector doesn't work correctly in this design
module mkCirShiftRegs (ShiftRegs#(size,data_t))
  provisos (Bits#(data_t,data_w), 
	    Log#(size, index_w));   

   // states
   Vector#(size, Reg#(data_t)) vRegs <- Vector::replicateM(mkReg(unpack(0)));
   Reg#(Bit#(index_w))   nextToWrite <- mkRegU;
   
   // constants
   Integer maxIndex = valueOf(size) - 1;
   Bit#(index_w) maxIdx = fromInteger(maxIndex);
   Bit#(index_w) nextToRead = nextToWrite;
   
   // functions
   function Bit#(index_w) incr (Bit#(index_w) n);
      let result = (n == maxIdx) ? 0 : n + 1;
      return result;
   endfunction // Bit

   method Action enq(x);
      (vRegs[nextToWrite])._write(x);
      nextToWrite <= incr(nextToWrite);
   endmethod
     
   method data_t first();
      return (vRegs[nextToRead])._read;
   endmethod
   
   method Action clear();
      for (Integer i = 0; i <= maxIndex; i = i + 1)
	(vRegs[fromInteger(i)])._write(unpack(0));
   endmethod

   method Vector#(size, data_t) getVector();
      Vector#(size, data_t) outVec = newVector;
      Bit#(index_w) idx = nextToWrite;
      for (Integer i = 0; i <= maxIndex; i = i + 1)
	begin
	   outVec[i] = (vRegs[idx])._read;
	   idx = incr(idx);
	end
      return outVec;
   endmethod
      
endmodule // mkDelay

// circular pointer approach, note that getVector doesn't work correctly in this design
module mkCirShiftRegsNoGetVec (ShiftRegs#(size,data_t))
  provisos (Bits#(data_t,data_w), 
	    Log#(size, index_w));   

   // states
   Vector#(size, Reg#(data_t)) vRegs <- Vector::replicateM(mkReg(unpack(0)));
   Reg#(Bit#(index_w))   nextToWrite <- mkRegU;
   
   // constants
   Integer maxIndex = valueOf(size) - 1;
   Bit#(index_w) maxIdx = fromInteger(maxIndex);
   Bit#(index_w) nextToRead = nextToWrite;

   // functions
   function Bit#(index_w) incr (Bit#(index_w) n);
      let result = (n == maxIdx) ? 0 : n + 1;
      return result;
   endfunction // Bit
   
   method Action enq(x);
      (vRegs[nextToWrite])._write(x);
      nextToWrite <= incr(nextToWrite);
   endmethod
     
   method data_t first();
      return (vRegs[nextToRead])._read;
   endmethod
   
   method Action clear();
      for (Integer i = 0; i <= maxIndex; i = i + 1)
	(vRegs[fromInteger(i)])._write(unpack(0));
   endmethod

   method Vector#(size, data_t) getVector();
      return newVector;
   endmethod
      
endmodule // mkDelay

