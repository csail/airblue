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
// A simple testbench of BitStreamFIFO
/////////////////////////////////////////////////////////////

//import BitStreamFIFO::*;

// Local includes
`include "asim/provides/airblue_special_fifos.bsh"

`define BufSz    8                      // fifo buffer size
`define BufBSz   TLog#(TAdd#(`BufSz,1)) // Bit#(BufBSz) ranges 0-BufSz
`define IOSz     8                      // max input size
`define IOBSz    TLog#(TAdd#(`IOSz,1))  // Bit#(IOBSz) ranges 0-IOSz
`define IODataSz 1                      // data element width
`define IOVecSz  TMul#(`IOSz,`IODataSz) // total no. bits to represent the input vector

(* synthesize *)
module mkBitStreamFIFOInstance(BitStreamFIFO#(`BufSz,`BufBSz,`IOSz,`IOBSz,`IODataSz));
   let fifo <- mkUGBitStreamLFIFO;
   return fifo;
endmodule

// (* synthesize *)
// module mkBitStreamFIFOTest(Empty);
   
module mkHWOnlyApplication (Empty);
   // state elements
   let                  fifo     <- mkBitStreamFIFOInstance;
   Reg#(Bit#(`IOVecSz)) enqData  <- mkReg(?);
   Reg#(Bit#(`IOBSz))   enqSz    <- mkReg(1);
   Reg#(Bit#(`IOBSz))   deqSz    <- mkReg(`IOSz);
   Reg#(Bit#(32))       clockCnt <- mkReg(0);
   Bit#(`BufBSz)        freeNo = fifo.free();
   Bit#(`BufBSz)        useNo  = fifo.usage();
   
   // rules
   rule enqFifo(zeroExtend(enqSz) <= freeNo);
      enqData <= enqData + 1;
      enqSz <= (enqSz != `IOSz) ? enqSz + 1 : 1;
      fifo.enq(enqSz,unpack(enqData));
      $display("At clock %d, enq %d bits with data %x",clockCnt,enqSz,enqData);
   endrule

   rule deqFifo(zeroExtend(deqSz) <= useNo);
      let deqData = fifo.first;
      fifo.deq(deqSz);
      deqSz <= (deqSz != `IOSz) ? deqSz + 1 : 1;
      $display("At clock %d, deq %d bits with data %x",clockCnt,deqSz,deqData);
   endrule

   rule advClock(True);
      clockCnt <= clockCnt + 1;
   endrule
   
   rule finish(clockCnt == 3000);
      $finish;
   endrule
endmodule

