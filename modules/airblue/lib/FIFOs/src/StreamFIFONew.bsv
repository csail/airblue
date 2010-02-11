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

/////////////////////////////////////////////////////////////
// Definition and Implementation of StreamFIFO
// Description: StreamFIFO is a fifo that can enq and deq 
// arbitrary no. elements
/////////////////////////////////////////////////////////////

import EHRReg::*;
import Vector::*;

/////////////////////////////////////////////////////////////
// Interface
// Name: StreamFIFO
// Ptrs: sz     : FIFO size
//       s_sz   : no. bits representing no. elements allowed to be enq/deq in one cycle
//       data_t : data element type
// Dscr: A fifo that can enq and deq arbitrary no. of 
//       elements
/////////////////////////////////////////////////////////////
interface StreamFIFO#(numeric type sz,     // buffer sz
		      numeric type s_sz,  
		      type data_t);        // basic data unit
      method Action enq(Bit#(s_sz) i_s_sz, 
			Vector#(sz, data_t) i_msg);
      method Vector#(sz, data_t) first();
      method Action deq(Bit#(s_sz) o_s_sz); 
      method Action clear();
      method Bool notEmpty(Bit#(s_sz) o_s_sz); // canDeq?
      method Bool notFull(Bit#(s_sz) i_s_sz);  // canEnq?
      method Bit#(s_sz) usage(); // no of slots used
      method Bit#(s_sz) free(); // no of slots unused
endinterface

//////////////////////////////////////////////////////////////
// Auxiliary Functions
/////////////////////////////////////////////////////////////

// turn Bit#(sz) to vector of 1 bit
function Vector#(sz,Bit#(1)) bit2Vec(Bit#(sz) val);
   return unpack(pack(val));
endfunction

// dynamic left shifter using barrel shifter
function Vector#(sz,data_t) shiftLeftBy(Vector#(sz,data_t) inVec,
					Bit#(s_sz) shiftBy)
   provisos (Bits#(data_t,data_sz));
   
   function Vector#(sz,data_t) stageFunc(Vector#(sz,data_t) iVec,
                                         Tuple2#(Bit#(1),Nat) ctrl);
      Nat shftAmnt = (tpl_1(ctrl) == 1) ? tpl_2(ctrl) : 0;
      return unpack(pack(iVec) << shftAmnt);
   endfunction
   
   Nat dataSz = fromInteger(valueOf(data_sz));
   Vector#(s_sz,Bit#(1)) shiftVec = unpack(shiftBy);
   Vector#(s_sz,Nat) natVec0 = genWith(fromInteger());
   Vector#(s_sz,Nat) natVec1 = map(\<< (1),natVec0);
   Vector#(s_sz,Nat) natVec2 = map(\* (dataSz),natVec1);
   let ctrlVec = zip(shiftVec, natVec2);
   return foldl(stageFunc,inVec,ctrlVec);
   
endfunction

// dynamic right shifter using barrel shifter
function Vector#(sz,data_t) shiftRightBy(Vector#(sz,data_t) inVec,
					 Bit#(s_sz) shiftBy)
   provisos (Bits#(data_t,data_sz));
   
   function Vector#(sz,data_t) stageFunc(Vector#(sz,data_t) iVec,
					 Tuple2#(Bit#(1),Nat) ctrl);
      Nat shftAmnt = (tpl_1(ctrl) == 1) ? tpl_2(ctrl) : 0;
      return unpack(pack(iVec) >> shftAmnt);
   endfunction
   
   Nat dataSz = fromInteger(valueOf(data_sz));
   Vector#(s_sz,Bit#(1)) shiftVec = unpack(shiftBy);
   Vector#(s_sz,Nat) natVec0 = genWith(fromInteger());
   Vector#(s_sz,Nat) natVec1 = map(\<< (1),natVec0);
   Vector#(s_sz,Nat) natVec2 = map(\* (dataSz),natVec1);
   let ctrlVec = zip(shiftVec, natVec2);
   return foldl(stageFunc,inVec,ctrlVec);
   
endfunction

////////////////////////////////////////////////////////////////////
// Module
// Name: mkStreamFIFO
// Ptrs: 
// Dscr: Create an instance of StreamFIFO which is implemented with
//       shifting approach
// Notes: To enq/deq, caller needs to check notFull/notEmpty 
//        explicitly (unguarded) 
///////////////////////////////////////////////////////////////////
module mkStreamFIFO(StreamFIFO#(sz, s_sz, data_t))
   provisos (Add#(sz,1,szp1),  
             Log#(szp1,ssz), // calculate ssz so that Bit#(ssz) can store values 0 - sz
             Add#(xxA,s_sz,ssz), // s_sz <= ssz
             Bits#(data_t,data_sz));

   Bit#(ssz) maxS   = fromInteger(valueOf(TSub#(TExp#(s_sz),1)));
   Bit#(ssz) maxIdx = fromInteger(valueOf(sz));          // buffer size
   Reg#(Vector#(sz,data_t)) buffers <- mkReg(newVector); // data storage
   EHRReg#(2,Bit#(ssz)) freeReg <- mkEHRReg(maxIdx);     // no. free slots
   let usedNo = maxIdx - freeReg[0];                     // no. used slots
   
   method Action enq(Bit#(s_sz) i_s_sz, 
                     Vector#(sz, data_t) i_msg);
      let extBuffers = append(buffers, i_msg);           // append i_msg at the end of buffers
      let shfBuffers = shiftRightBy(extBuffers, i_s_sz); // shift the extended buffers    
      Vector#(sz, data_t) newBuffers = take(shfBuffers); // new buffers equals to first half of the buffer
      buffers <= newBuffers;
      freeReg[1] <= freeReg[1] - zeroExtend(i_s_sz);
   endmethod
   
   method Vector#(sz, data_t) first(); 
      // shift the data so that first data appeared at the beginning of the fifo
      return shiftRightBy(buffers,freeReg[0]);
   endmethod
   
   method Action deq(Bit#(s_sz) o_s_sz);
      // adjust the no. free slots
      freeReg[0] <= freeReg[0] + zeroExtend(o_s_sz);
   endmethod
   
   method Action clear();
      freeReg[1] <= maxIdx;
   endmethod
   
   method Bool notEmpty(Bit#(s_sz) o_s_sz);
      return usedNo >= zeroExtend(o_s_sz);
   endmethod
   
   method Bool notFull(Bit#(s_sz) i_s_sz);
      return freeReg[0] >= zeroExtend(i_s_sz);
   endmethod

   method Bit#(s_sz) usage() = (usedNo >= maxS) ? truncate(maxS) : truncate(usedNo) ; // no of slots used
   method Bit#(s_sz) free()  = (freeReg[0] >= maxS) ? truncate(maxS) : truncate(usedNo) ; // no of slots unused
       
endmodule

////////////////////////////////////////////////////////////////////
// Module
// Name: mkStreamLFIFO
// Ptrs: 
// Dscr: Create an instance of StreamFIFO which is implemented with
//       shifting approach, can deq and enq parallelly when it is full
// Notes: To enq/deq, caller needs to check notFull/notEmpty 
//        explicitly  
///////////////////////////////////////////////////////////////////
module mkStreamLFIFO(StreamFIFO#(sz, s_sz, data_t))
   provisos (Add#(sz,1,szp1),  
             Log#(szp1,ssz), // calculate ssz so that Bit#(ssz) can store values 0 - sz
             Add#(xxA,s_sz,ssz), // s_sz <= ssz
             Bits#(data_t,data_sz));
   
   Bit#(ssz) maxS   = fromInteger(valueOf(TSub#(TExp#(s_sz),1)));
   Bit#(ssz) maxIdx = fromInteger(valueOf(sz));          // buffer size
   Reg#(Vector#(sz,data_t)) buffers <- mkReg(newVector); // data storage
   EHRReg#(2,Bit#(ssz)) freeReg <- mkEHRReg(maxIdx);     // no. free slots
   let usedNo = maxIdx - freeReg[0];                     // no. used slots
   
   method Action enq(Bit#(s_sz) i_s_sz, 
                     Vector#(sz, data_t) i_msg);
      let extBuffers = append(buffers, i_msg);           // append i_msg at the end of buffers
      let shfBuffers = shiftRightBy(extBuffers, i_s_sz); // shift the extended buffers    
      Vector#(sz, data_t) newBuffers = take(shfBuffers); // new buffers equals to first half of the buffer
      buffers <= newBuffers;
      freeReg[1] <= freeReg[1] - zeroExtend(i_s_sz);
   endmethod
   
   method Vector#(sz, data_t) first(); 
      return shiftRightBy(buffers,freeReg[0]);
   endmethod
   
   method Action deq(Bit#(s_sz) o_s_sz); 
      freeReg[0] <= freeReg[0] + zeroExtend(o_s_sz);
   endmethod
   
   method Action clear();
      freeReg[1] <= maxIdx;
   endmethod
   
   method Bool notEmpty(Bit#(s_sz) o_s_sz);
      return usedNo >= zeroExtend(o_s_sz);
   endmethod
   
   method Bool notFull(Bit#(s_sz) i_s_sz);
      return freeReg[0] >= zeroExtend(i_s_sz);
   endmethod

   method Bit#(s_sz) usage() = (usedNo >= maxS) ? truncate(maxS) : truncate(usedNo) ; // no of slots used
   method Bit#(s_sz) free()  = (freeReg[0] >= maxS) ? truncate(maxS) : truncate(usedNo) ; // no of slots unused
   
endmodule

