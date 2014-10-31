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

import EHRReg::*;
import Vector::*;

/////////////////////////////////////////////////////////////
// Interface
// Name: StreamFIFO
// Ptrs: sz, s_sz, data_t
// Dscr: A fifo that can enq and deq arbitrary no. of 
//       elements
/////////////////////////////////////////////////////////////
interface StreamFIFO#(numeric type sz,     // buffer sz
		      numeric type s_sz,   // shift sz
		      type data_t);        // basic data unit
      method Action enq(Bit#(s_sz) i_s_sz, 
			Vector#(sz, data_t) i_msg);
      method Vector#(sz, data_t) first();
      method Action deq(Bit#(s_sz) o_s_sz); 
      method Action clear();
      method Bool notEmpty(Bit#(s_sz) o_s_sz); // canDeq?
      method Bool notFull(Bit#(s_sz) i_s_sz);  // canEnq?
//      method Bit#(s_sz) usage(); // no of slots used
//      method Bit#(s_sz) free(); // no of slots unused
endinterface

//////////////////////////////////////////////////////////////
// Functions
/////////////////////////////////////////////////////////////
// shift towards higher index
function Vector#(sz,data_t) shiftLeftBy(Vector#(sz,data_t) inVec,
					Bit#(s_sz) shiftBy)
   provisos (Add#(sz,1,szp1),
	     Log#(szp1,s_sz),
	     Bits#(data_t,data_sz));
   
   function Vector#(sz,data_t) stageFunc(Vector#(sz,data_t) iVec,
					 Tuple2#(Bit#(1),Nat) ctrl);
      return (tpl_1(ctrl) == 1) ? 
             unpack(pack(iVec) << tpl_2(ctrl)) : 
             iVec;
   endfunction
   
   Nat dataSz = fromInteger(valueOf(data_sz));
   Vector#(s_sz,Bit#(1)) shiftVec = unpack(shiftBy);
   Vector#(s_sz,Nat) natVec0 = genWith(fromInteger);
   Vector#(s_sz,Nat) natVec1 = map(\<< (1),natVec0);
   Vector#(s_sz,Nat) natVec2 = map(\* (dataSz),natVec1);
   let ctrlVec = zip(shiftVec, natVec2);
   return foldl(stageFunc,inVec,ctrlVec);
   
endfunction

// shift towards lower index
function Vector#(sz,data_t) shiftRightBy(Vector#(sz,data_t) inVec,
					 Bit#(s_sz) shiftBy)
   provisos (Add#(sz,1,szp1),
	     Log#(szp1,s_sz),
	     Bits#(data_t,data_sz));
   
   function Vector#(sz,data_t) stageFunc(Vector#(sz,data_t) iVec,
					 Tuple2#(Bit#(1),Nat) ctrl);
      return (tpl_1(ctrl) == 1) ? 
             unpack(pack(iVec) >> tpl_2(ctrl)) : 
             iVec;
   endfunction
   
   Nat dataSz = fromInteger(valueOf(data_sz));
   Vector#(s_sz,Bit#(1)) shiftVec = unpack(shiftBy);
   Vector#(s_sz,Nat) natVec0 = genWith(fromInteger);
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
             Log#(szp1,s_sz), // calculate s_sz so that Bit#(s_sz) can store values 0 - sz
             Add#(xxA,s_sz,TLog#(TAdd#(TAdd#(sz,sz),1))),
             Bits#(data_t,data_sz));
   
   Bit#(s_sz) maxIdx = fromInteger(valueOf(sz));          // buffer size
   Reg#(Vector#(sz,data_t)) buffers <- mkReg(newVector); // data storage
   EHRReg#(2,Bit#(s_sz)) freeReg <- mkEHRReg(maxIdx);     // no. free slots
   let usedNo = maxIdx - freeReg[0];                     // no. used slots
   
   method Action enq(Bit#(s_sz) i_s_sz, 
                     Vector#(sz, data_t) i_msg);
      let extBuffers = append(buffers, i_msg);           // append i_msg at the end of buffers
      let shfBuffers = shiftRightBy(extBuffers, zeroExtend(i_s_sz)); // shift the extended buffers    
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
   
//   method Bit#(s_sz) usage();
//      return usedNo;
//   endmethod
   
//   method Bit#(s_sz) free();
//      return freeReg[0];
///   endmethod
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
             Log#(szp1,s_sz), // calculate s_sz so that Bit#(s_sz) can store values 0 - sz
             Add#(xxA,s_sz,TLog#(TAdd#(TAdd#(sz,sz),1))),
             Bits#(data_t,data_sz));
   
   Bit#(s_sz) maxIdx = fromInteger(valueOf(sz));          // buffer size
   Reg#(Vector#(sz,data_t)) buffers <- mkReg(newVector); // data storage
   EHRReg#(2,Bit#(s_sz)) freeReg <- mkEHRReg(maxIdx);     // no. free slots
   let usedNo = maxIdx - freeReg[0];                     // no. used slots
   
   method Action enq(Bit#(s_sz) i_s_sz, 
                     Vector#(sz, data_t) i_msg);
      let extBuffers = append(buffers, i_msg);           // append i_msg at the end of buffers
      let shfBuffers = shiftRightBy(extBuffers, zeroExtend(i_s_sz)); // shift the extended buffers    
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
   
//   method Bit#(s_sz) usage();
//      return usedNo;
//   endmethod
   
//   method Bit#(s_sz) free();
//      return freeReg[0];
//   endmethod
endmodule

// ////////////////////////////////////////////////////////////////////
// // Module
// // Name: mkStreamFIFO
// // Ptrs: 
// // Dscr: Create an instance of StreamFIFO which is implemented with
// //       shifting approach
// // Notes: To enq/deq, caller needs to check notFull/notEmpty 
// //        explicitly  
// ///////////////////////////////////////////////////////////////////
// module mkStreamFIFO(StreamFIFO#(sz, s_sz, data_t))
//    provisos (Add#(sz,1,szp1),
// 	     Log#(szp1,s_sz),
// 	     Bits#(data_t,data_sz));
   
//    Bit#(s_sz) maxTail = fromInteger(valueOf(sz));
//    EHRReg#(2,Vector#(sz,data_t)) buffer <- mkEHRReg(newVector);       
//    EHRReg#(2,Bit#(s_sz)) tail <- mkEHRReg(0); // equal to usage
   
//    function data_t selTuple(Tuple3#(Bool,data_t,data_t) tup);
//       return tpl_1(tup) ? tpl_2(tup) : tpl_3(tup);
//    endfunction

//    method Action enq(Bit#(s_sz) i_s_sz, 
// 		     Vector#(sz, data_t) i_msg);
//       let buffer0 = buffer[1];
//       let buffer1 = shiftLeftBy(i_msg, tail[1]);
//       Vector#(sz, Bit#(s_sz)) idxVec = genWith(fromInteger);
//       Vector#(sz, Bool) selBuffer = map(\> (tail[1]), idxVec);
//       let zipBuffer = zip3(selBuffer,buffer0,buffer1);
//       let newBuffer = map(selTuple,zipBuffer);
//       buffer[1] <= newBuffer;
//       tail[1] <= tail[1] + i_s_sz;
//    endmethod
   
//    method Vector#(sz, data_t) first(); 
//       return buffer[0];
//    endmethod
   
//    method Action deq(Bit#(s_sz) o_s_sz);
//       buffer[0] <= shiftRightBy(buffer[0], o_s_sz);
//       tail[0] <= tail[0] - o_s_sz;
//    endmethod
   
//    method Action clear();
//       tail[1] <= 0;
//    endmethod
   
//    method Bool notEmpty(Bit#(s_sz) o_s_sz);
//       return tail[0] >= o_s_sz;
//    endmethod
   
//    method Bool notFull(Bit#(s_sz) i_s_sz);
//       return tail[0] <= maxTail - i_s_sz;
//    endmethod
   
//    method Bit#(s_sz) usage();
//       return tail[0];
//    endmethod
   
//    method Bit#(s_sz) free();
//       return maxTail - tail[0];
//    endmethod
// endmodule

// ////////////////////////////////////////////////////////////////////
// // Module
// // Name: mkStreamLFIFO
// // Ptrs: 
// // Dscr: Create an instance of StreamFIFO which is implemented with
// //       shifting approach, can deq and enq parallelly when it is full
// // Notes: To enq/deq, caller needs to check notFull/notEmpty 
// //        explicitly  
// ///////////////////////////////////////////////////////////////////
// module mkStreamLFIFO(StreamFIFO#(sz, s_sz, data_t))
//    provisos (Add#(sz,1,szp1),
// 	     Log#(szp1,s_sz),
// 	     Bits#(data_t,data_sz));
   
//    Bit#(s_sz) maxTail = fromInteger(valueOf(sz));
//    EHRReg#(2,Vector#(sz,data_t)) buffer <- mkEHRReg(newVector);       
//    EHRReg#(2,Bit#(s_sz)) tail <- mkEHRReg(0); // equal to usage
   
//    function data_t selTuple(Tuple3#(Bool,data_t,data_t) tup);
//       return tpl_1(tup) ? tpl_2(tup) : tpl_3(tup);
//    endfunction

//    method Action enq(Bit#(s_sz) i_s_sz, 
// 		     Vector#(sz, data_t) i_msg);
//       let buffer0 = buffer[1];
//       let buffer1 = shiftLeftBy(i_msg, tail[1]);
//       Vector#(sz, Bit#(s_sz)) idxVec = genWith(fromInteger);
//       Vector#(sz, Bool) selBuffer = map(\> (tail[1]), idxVec);
//       let zipBuffer = zip3(selBuffer,buffer0,buffer1);
//       let newBuffer = map(selTuple,zipBuffer);
//       buffer[1] <= newBuffer;
//       tail[1] <= tail[1] + i_s_sz;
//    endmethod
   
//    method Vector#(sz, data_t) first(); 
//       return buffer[0];
//    endmethod
   
//    method Action deq(Bit#(s_sz) o_s_sz);
//       buffer[0] <= shiftRightBy(buffer[0], o_s_sz);
//       tail[0] <= tail[0] - o_s_sz;
//    endmethod
   
//    method Action clear();
//       tail[1] <= 0;
//    endmethod
   
//    method Bool notEmpty(Bit#(s_sz) o_s_sz);
//       return tail[0] >= o_s_sz;
//    endmethod
   
//    method Bool notFull(Bit#(s_sz) i_s_sz);
//       return tail[1] <= maxTail - i_s_sz; // slower ready signal 
//    endmethod

//    method Bit#(s_sz) usage();
//       return tail[0];
//    endmethod
   
//    method Bit#(s_sz) free();
//       return maxTail - tail[1];
//    endmethod   
// endmodule

