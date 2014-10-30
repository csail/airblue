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

// import EHRReg::*;
import Vector::*;
import GetPut::*;

// Local includes
import AirblueCommon::*;

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
      method Bit#(s_sz) usage(); // no of slots used
      method Bit#(s_sz) free(); // no of slots unused
endinterface

//////////////////////////////////////////////////////////////
// Functions
/////////////////////////////////////////////////////////////
// shift towards higher index
// function Vector#(sz,data_t) shiftLeftBy(Vector#(sz,data_t) in_vec,
// 					Bit#(s_sz) shift_by)
//    provisos (Add#(sz,1,szp1),
// 	     Log#(szp1,s_sz),
// 	     Bits#(data_t,data_sz));
   
//    function Vector#(sz,data_t) stageFunc(Vector#(sz,data_t) i_vec,
// 					 Tuple2#(Bit#(1),Nat) ctrl);
//       return (tpl_1(ctrl) == 1) ? 
//              unpack(pack(i_vec) << tpl_2(ctrl)) : 
//              i_vec;
//    endfunction
   
//    Nat data_sz = fromInteger(valueOf(data_sz));
//    Vector#(s_sz,Bit#(1)) shift_vec = unpack(shift_by);
//    Vector#(s_sz,Nat) nat_vec0 = genWith(fromInteger);
//    Vector#(s_sz,Nat) nat_vec1 = map(\<< (1),nat_vec0);
//    Vector#(s_sz,Nat) nat_vec2 = map(\* (data_sz),nat_vec1);
//    let ctrl_vec = zip(shift_vec, nat_vec2);
//    return foldl(stageFunc,in_vec,ctrl_vec);
   
// endfunction

// shift towards lower index
// function Vector#(sz,data_t) shiftRightBy(Vector#(sz,data_t) in_vec,
// 					 Bit#(s_sz) shift_by)
//    provisos (Add#(sz,1,szp1),
// 	     Log#(szp1,s_sz),
// 	     Bits#(data_t,data_sz));
   
//    function Vector#(sz,data_t) stageFunc(Vector#(sz,data_t) i_vec,
// 					 Tuple2#(Bit#(1),Nat) ctrl);
//       return (tpl_1(ctrl) == 1) ? 
//              unpack(pack(i_vec) >> tpl_2(ctrl)) : 
//              i_vec;
//    endfunction
   
//    Nat data_sz = fromInteger(valueOf(data_sz));
//    Vector#(s_sz,Bit#(1)) shift_vec = unpack(shift_by);
//    Vector#(s_sz,Nat) nat_vec0 = genWith(fromInteger);
//    Vector#(s_sz,Nat) nat_vec1 = map(\<< (1),nat_vec0);
//    Vector#(s_sz,Nat) nat_vec2 = map(\* (data_sz),nat_vec1);
//    let ctrl_vec = zip(shift_vec, nat_vec2);
//    return foldl(stageFunc,in_vec,ctrl_vec);
   
// endfunction

// shift towards higher index
function Vector#(sz,data_t) shiftLeftBy(Vector#(sz,data_t) in_vec,
                                        Bit#(s_sz) shift_by)
   provisos (Bits#(data_t,data_sz),
             Mul#(sz,data_sz,t_sz),
             Add#(t_sz,1,t_sz_p_1),
             Log#(t_sz_p_1,t_s_sz),
             Add#(xxA,s_sz,t_s_sz));
   
   // calculate the left shift amount
   Bit#(t_s_sz) shft_amnt = zeroExtend(shift_by) * fromInteger(valueOf(data_sz));
   return unpack(pack(in_vec) << shft_amnt);
      
endfunction

// shift towards lower index
function Vector#(sz,data_t) shiftRightBy(Vector#(sz,data_t) in_vec,
					 Bit#(s_sz) shift_by)
   provisos (Bits#(data_t,data_sz),
             Mul#(sz,data_sz,t_sz),
             Add#(t_sz,1,t_sz_p_1),
             Log#(t_sz_p_1,t_s_sz),
             Add#(xxA,s_sz,t_s_sz));
   
   // calculate the right shift amount
   Bit#(t_s_sz) shft_amnt = zeroExtend(shift_by) * fromInteger(valueOf(data_sz));
   return unpack(pack(in_vec) >> shft_amnt);
      
endfunction


////////////////////////////////////////////////////////////////////
// Module
// Name: mkStreamFIFO
// Ptrs: 
// Dscr: Create an instance of StreamFIFO which is implemented with
//       shifting approach
// Notes: To enq/deq, caller needs to check notFull/notEmpty 
//        explicitly  
///////////////////////////////////////////////////////////////////
module mkStreamFIFO(StreamFIFO#(sz, s_sz, data_t))
   provisos (Bits#(data_t,data_sz),
             Mul#(sz,data_sz,t_sz),
             Add#(t_sz,1,t_sz_p_1),
             Log#(t_sz_p_1,t_s_sz),
             Add#(xxA,s_sz,t_s_sz));
//    provisos (Add#(sz,1,szp1),
// 	     Log#(szp1,s_sz),
// 	     Bits#(data_t,data_sz));
   
   Bit#(s_sz) max_tail = fromInteger(valueOf(sz));
   EHRReg#(2,Vector#(sz,data_t)) buffer <- mkEHRReg(newVector);       
   EHRReg#(2,Bit#(s_sz)) tail <- mkEHRReg(0); // equal to usage
   
   function data_t selTuple(Tuple3#(Bool,data_t,data_t) tup);
      return tpl_1(tup) ? tpl_2(tup) : tpl_3(tup);
   endfunction

   method Action enq(Bit#(s_sz) i_s_sz, 
		     Vector#(sz, data_t) i_msg);
      let buffer0 = buffer[1];
      let buffer1 = shiftLeftBy(i_msg, tail[1]);
      Vector#(sz, Bit#(s_sz)) idx_vec = genWith(fromInteger);
      Vector#(sz, Bool) sel_buffer = map(\> (tail[1]), idx_vec);
      let zip_buffer = zip3(sel_buffer,buffer0,buffer1);
      let new_buffer = map(selTuple,zip_buffer);
      buffer[1] <= new_buffer;
      tail[1] <= tail[1] + i_s_sz;
   endmethod
   
   method Vector#(sz, data_t) first(); 
      return buffer[0];
   endmethod
   
   method Action deq(Bit#(s_sz) o_s_sz);
      buffer[0] <= shiftRightBy(buffer[0], o_s_sz);
      tail[0] <= tail[0] - o_s_sz;
   endmethod
   
   method Action clear();
      tail[1] <= 0;
   endmethod
   
   method Bool notEmpty(Bit#(s_sz) o_s_sz);
      return tail[0] >= o_s_sz;
   endmethod
   
   method Bool notFull(Bit#(s_sz) i_s_sz);
      return tail[0] <= max_tail - i_s_sz;
   endmethod
   
   method Bit#(s_sz) usage();
      return tail[0];
   endmethod
   
   method Bit#(s_sz) free();
      return max_tail - tail[0];
   endmethod
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
   provisos (Bits#(data_t,data_sz),
             Mul#(sz,data_sz,t_sz),
             Add#(t_sz,1,t_sz_p_1),
             Log#(t_sz_p_1,t_s_sz),
             Add#(xxA,s_sz,t_s_sz));
//    provisos (Add#(sz,1,szp1),
// 	     Log#(szp1,s_sz),
// 	     Bits#(data_t,data_sz));
   
   Bit#(s_sz) max_tail = fromInteger(valueOf(sz));
   EHRReg#(2,Vector#(sz,data_t)) buffer <- mkEHRReg(newVector);       
   EHRReg#(2,Bit#(s_sz)) tail <- mkEHRReg(0); // equal to usage
   
   function data_t selTuple(Tuple3#(Bool,data_t,data_t) tup);
      return tpl_1(tup) ? tpl_2(tup) : tpl_3(tup);
   endfunction

   method Action enq(Bit#(s_sz) i_s_sz, 
		     Vector#(sz, data_t) i_msg);
      let buffer0 = buffer[1];
      let buffer1 = shiftLeftBy(i_msg, tail[1]);
      Vector#(sz, Bit#(s_sz)) idx_vec = genWith(fromInteger);
      Vector#(sz, Bool) sel_buffer = map(\> (tail[1]), idx_vec);
      let zip_buffer = zip3(sel_buffer,buffer0,buffer1);
      let new_buffer = map(selTuple,zip_buffer);
      buffer[1] <= new_buffer;
      tail[1] <= tail[1] + i_s_sz;
   endmethod
   
   method Vector#(sz, data_t) first(); 
      return buffer[0];
   endmethod
   
   method Action deq(Bit#(s_sz) o_s_sz);
      buffer[0] <= shiftRightBy(buffer[0], o_s_sz);
      tail[0] <= tail[0] - o_s_sz;
   endmethod
   
   method Action clear();
      tail[1] <= 0;
   endmethod
   
   method Bool notEmpty(Bit#(s_sz) o_s_sz);
      return tail[0] >= o_s_sz;
   endmethod
   
   method Bool notFull(Bit#(s_sz) i_s_sz);
      return tail[1] <= max_tail - i_s_sz; // slower ready signal 
   endmethod

   method Bit#(s_sz) usage();
      return tail[0];
   endmethod
   
   method Bit#(s_sz) free();
      return max_tail - tail[1];
   endmethod   
endmodule

// GetPut
instance ToGet#(StreamFIFO#(sz,s_sz,b),Vector#(n,b)) provisos (Add#(n,xxx,sz));
   function Get#(Vector#(n,b)) toGet(StreamFIFO#(sz,s_sz,b) fifo);
      Bit#(s_sz) nv = fromInteger(valueOf(n));
      return interface Get#(Vector#(n,b));
         method ActionValue#(Vector#(n,b)) get() if(fifo.notEmpty(nv));
            fifo.deq(nv);
            return take(fifo.first);
         endmethod
      endinterface;
   endfunction
endinstance

instance ToPut#(StreamFIFO#(sz,s_sz,b),Vector#(n,b)) provisos (Add#(n,xxx,sz));
   function Put#(Vector#(n,b)) toPut(StreamFIFO#(sz,s_sz,b) fifo);
      Bit#(s_sz) nv = fromInteger(valueOf(n));
      return interface Put#(Vector#(n,b));
         method Action put(Vector#(n,b) x) if (fifo.notFull(nv));
            fifo.enq(nv, append(x, ?));
         endmethod
      endinterface;
   endfunction
endinstance
