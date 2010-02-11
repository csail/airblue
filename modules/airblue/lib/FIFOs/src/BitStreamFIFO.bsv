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
// Interface and Implementation of BitStreamFIFO
// Description: BitStreamFIFO is a fifo that can enq and deq 
//              arbitrary no. bits
/////////////////////////////////////////////////////////////

import Vector::*;

/////////////////////////////////////////////////////////////
// Interface
// Name: BitStreamFIFO
// Description: A fifo that can enq and deq arbitrary no. elements
// Parameters: buf_sz    : FIFO buffer size
//             buf_bsz   : buffer index size in no. bits
//             io_sz     : max no. io_sz data element can be enq/deq at one time
//             io_bsz    : no. bits to specify the element to be enq/deq at one time
//             io_data_sz: data element size in no. bits
// Methods: enq  : enqueue the first i_b elements in i_data to 
//                 the end of the fifo
//          first: read o_sz elements from the start of fifo
//          deq  : dequeue the o_b elements from the start of fifo
//          clear: clear the fifo
//          usage: return no. buffer used in the fifo
//          free:  return no. buffer free in the fifo          
/////////////////////////////////////////////////////////////
interface BitStreamFIFO#(numeric type buf_sz,
                         numeric type buf_bsz,
                         numeric type io_sz,
                         numeric type io_bsz,
                         numeric type io_data_sz);
   method Action enq(Bit#(io_bsz) i_sz,    
                     Vector#(io_sz,Bit#(io_data_sz))  i_data);
   method Vector#(io_sz,Bit#(io_data_sz)) first();            
   method Action deq(Bit#(io_bsz) o_sz);   
   method Action clear();                
   method Bit#(buf_bsz) usage();            
   method Bit#(buf_bsz) free();            
endinterface

//////////////////////////////////////////////////////////////
// Auxiliary Functions
/////////////////////////////////////////////////////////////

// dynamic left shifter using barrel shifter
function Vector#(sz,Bit#(data_sz)) shiftLeft(Vector#(sz,Bit#(data_sz)) i_data, // input data
                                             Bit#(s_sz) shift); // left shift amount
   
   function Tuple2#(Bit#(a),Nat) 
      stageFunc(Tuple2#(Bit#(a),Nat) in, Bool ctrl);
      let in_data      = tpl_1(in);
      let in_shift     = tpl_2(in);
      let new_in_data  = ctrl ? in_data << in_shift : in_data;
      let new_in_shift = in_shift << 1;
      return tuple2(new_in_data,new_in_shift);
   endfunction

   Vector#(s_sz,Bool) ctrlVec = unpack(pack(shift));
   Nat seed = fromInteger(valueOf(data_sz));
   let i_data_b = pack(i_data);
   let resTpl = foldl(stageFunc,tuple2(i_data_b,seed),ctrlVec);
   return unpack(tpl_1(resTpl));
      
endfunction

// dynamic right shifter using barrel shifter
function Vector#(sz,Bit#(data_sz)) shiftRight(Vector#(sz,Bit#(data_sz)) i_data, // input data
                                              Bit#(s_sz) shift); // right shift amount
   
   function Tuple2#(Bit#(a),Nat) 
      stageFunc(Tuple2#(Bit#(a),Nat) in, Bool ctrl);
      let in_data      = tpl_1(in);
      let in_shift     = tpl_2(in);
      let new_in_data  = ctrl ? in_data >> in_shift : in_data;
      let new_in_shift = in_shift << 1;
      return tuple2(new_in_data,new_in_shift);
   endfunction

   Vector#(s_sz,Bool) ctrlVec = unpack(pack(shift));
   Nat seed = fromInteger(valueOf(data_sz));
   let i_data_b = pack(i_data);
   let resTpl = foldl(stageFunc,tuple2(i_data_b,seed),ctrlVec);
   return unpack(tpl_1(resTpl));
      
endfunction


////////////////////////////////////////////////////////////////////
// Module Defintion
// Name: mkUGBitStreamFIFO
// Description: Implementation of BitStreamFIFO interface
//              with shifters, methods enq/deq are unguarded, 
//              user of this module needs to check usage and free 
//              explicitly to guarantee correctness
// Schedule: enq CF {first, deq, usage, free}
//           enq SB clear
//           enq C  enq
//           first CF {enq, first, deq, usage ,free}
//           first SB clear
//           deq CF {enq, first, usage, free}
//           deq SB clear
//           deq C  deq
//           clear SB clear
//           clear SA {enq, first, deq, usage, free}
//           usage CF {enq, first, deq, usage, free}
//           usage SB clear
//           free CF {enq, first, deq, usage, free}
//           free SB clear
///////////////////////////////////////////////////////////////////
module mkUGBitStreamFIFO(BitStreamFIFO#(buf_sz,buf_bsz,io_sz,io_bsz,io_data_sz))
   provisos (Add#(buf_sz,1,buf_szp1),
             Log#(buf_szp1,buf_bsz),    // Bit#(buf_bsz) ranges 0-buf_sz
             Add#(io_sz,1,io_szp1),
             Log#(io_szp1,io_bsz),      // Bit#(io_bsz) ranges 0-io_sz
             Add#(xxA,io_bsz,buf_bsz),  // io_bsz < buf_bsz
             Add#(io_sz,xxB,buf_sz));   // io_sz < buf_sz 
   
   Bit#(buf_bsz) maxIdx = fromInteger(valueOf(buf_sz));
   Reg#(Vector#(buf_sz,Bit#(io_data_sz))) buffers <- mkReg(newVector);
   Reg#(Bit#(buf_bsz)) freeNo <- mkReg(maxIdx);
   Reg#(Bit#(buf_bsz)) useNo  <- mkReg(0);
   Wire#(Bit#(io_bsz)) subFree <- mkDWire(0);
   Wire#(Bit#(io_bsz)) addFree <- mkDWire(0);
   Bit#(io_bsz) addUse = subFree;
   Bit#(io_bsz) subUse = addFree;
   Wire#(Vector#(buf_sz,Bit#(io_data_sz))) newBuffers <- mkDWire(buffers);
   
   // adjust the freeNo/ussNo/buffers dependings on whether enq/deq has been called
   rule updateState(True);
      freeNo <= freeNo + zeroExtend(addFree) - zeroExtend(subFree);
      useNo  <= useNo + zeroExtend(addUse) - zeroExtend(subUse);
      buffers <= newBuffers;
   endrule
   
   method Action enq(Bit#(io_bsz) i_b,Vector#(io_sz,Bit#(io_data_sz)) i_data);
      let extBuffers  = append(buffers,i_data);     // append i_data at the end of buffers
      let shftBuffers = shiftRight(extBuffers,i_b); // shift the extended buffers by i_b elements    
      newBuffers <= take(shftBuffers);              // save back the data
      subFree <= i_b;                               // add i_b to freeNo
   endmethod
   
   method Vector#(io_sz,Bit#(io_data_sz)) first(); 
      // shift the data so that first element at lsbs
      let shftBuffers = shiftRight(buffers,freeNo);
      return take(shftBuffers);
   endmethod
   
   method Action deq(Bit#(io_bsz) o_b);
      addFree <= o_b; // sub o_b to freeNo
   endmethod
   
   method Action clear();
      freeNo <= maxIdx;   // reset freeNo
      useNo <= 0;
   endmethod
   
   method Bit#(buf_bsz) usage();
      return useNo;
   endmethod
   
   method Bit#(buf_bsz) free();
      return freeNo;
   endmethod
   
endmodule

////////////////////////////////////////////////////////////////////
// Module Defintion
// Name: mkUGBitStreamLFIFO
// Description: Implementation of BitStreamFIFO interface
//              with shifters, methods enq/deq are unguarded, 
//              user of this module needs to check usage and free 
//              explicitly to guarantee correctness, free returns
//              the value after deq  
// Schedule: enq CF {first, deq, usage, free}
//           enq SB clear
//           enq C  enq
//           first CF {enq, first, deq, usage ,free}
//           first SB clear
//           deq CF {enq, first, usage}
//           deq SB {free, clear}
//           deq C  deq
//           clear SB clear
//           clear SA {enq, first, deq, usage, free}
//           usage CF {enq, first, deq, usage, free}
//           usage SB clear
//           free CF {enq, first, usage, free}
//           free SB clear
//           free SA deq              
///////////////////////////////////////////////////////////////////
module mkUGBitStreamLFIFO(BitStreamFIFO#(buf_sz,buf_bsz,io_sz,io_bsz,io_data_sz))
   provisos (Add#(buf_sz,1,buf_szp1),
             Log#(buf_szp1,buf_bsz),   // Bit#(buf_bsz) ranges 0-buf_sz
             Add#(io_sz,1,io_szp1),
             Log#(io_szp1,io_bsz),     // Bit#(io_bsz) ranges 0-io_sz
             Add#(xxA,io_bsz,buf_bsz), // io_bsz < buf_bsz
             Add#(io_sz,xxB,buf_sz));  // io_sz < buf_sz 
   
   Bit#(buf_bsz) maxIdx = fromInteger(valueOf(buf_sz));
   Reg#(Vector#(buf_sz,Bit#(io_data_sz))) buffers <- mkReg(newVector);
   Reg#(Bit#(buf_bsz)) freeNo <- mkReg(maxIdx);
   Reg#(Bit#(buf_bsz)) useNo  <- mkReg(0);
   Wire#(Bit#(io_bsz)) subFree <- mkDWire(0);
   Wire#(Bit#(io_bsz)) addFree <- mkDWire(0);
   Bit#(io_bsz) addUse = subFree;
   Bit#(io_bsz) subUse = addFree;
   Wire#(Vector#(buf_sz,Bit#(io_data_sz))) newBuffers <- mkDWire(buffers);
   
   // adjust the freeNo dependings on whether enq/deq has been called
   rule updateFreeNo(True);
      freeNo <= freeNo + zeroExtend(addFree) - zeroExtend(subFree);
      useNo <= useNo + zeroExtend(addUse) - zeroExtend(subUse);
      buffers <= newBuffers;
   endrule
   
   method Action enq(Bit#(io_bsz) i_b,Vector#(io_sz,Bit#(io_data_sz)) i_data);
      let extBuffers  = append(buffers,i_data);     // append i_data at the end of buffers
      let shftBuffers = shiftRight(extBuffers,i_b); // shift the extended buffers by i_b elements    
      newBuffers <= take(shftBuffers);              // save back the data
      subFree <= i_b;                               // add i_b to freeNo
   endmethod
   
   method Vector#(io_sz,Bit#(io_data_sz)) first(); 
      // shift the data so that first bit at lsb
      let shftBuffers = shiftRight(buffers,freeNo);
      return take(shftBuffers);
   endmethod
   
   method Action deq(Bit#(io_bsz) o_b);
      addFree <= o_b; // add o_b to freeNo
   endmethod
   
   method Action clear();
      freeNo <= maxIdx;   // reset freeNo
   endmethod
   
   method Bit#(buf_bsz) usage();
      return useNo;
   endmethod
   
   method Bit#(buf_bsz) free();
      return freeNo + zeroExtend(addFree);
   endmethod
   
endmodule