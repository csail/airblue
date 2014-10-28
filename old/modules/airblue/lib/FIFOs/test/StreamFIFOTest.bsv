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

//import StreamFIFO::*;
import Vector::*;

// Local includes
`include "asim/provides/airblue_special_fifos.bsh"

`define BufferSz 8 // at most 2^16
`define SSz      TLog#(TAdd#(`BufferSz,1))
`define MaxSSz   `BufferSz
//`define SSz      4
//`define MaxSSz   fromInteger(valueOf(TExp#(`SSz))-1)
`define DataSz   32 // allowed range 9-32 
`define EndCycle 300000 //how many cycles the testbench to run?

// get next random data
import "BDPI" function Bit#(`DataSz) getNextData();

// set new fifo size, also clear the fifo
import "BDPI" function Bool setStreamFIFOSize(Bit#(16) sz);

// enq sz data into stream fifo, the first element is in_data, followed by in_data+1...etc
import "BDPI" function Bool enqStreamFIFO(Bit#(`DataSz) in_data, Bit#(16) sz);

// dequeue sz data from the head of stream fifo, return the first element                                  
import "BDPI" function Bit#(`DataSz) deqStreamFIFO(Bit#(16) sz);

// clear stream fifo
import "BDPI" function Bool clearStreamFIFO();

// return the no. element in the stream fifo
import "BDPI" function Bit#(16) getStreamFIFOUsage();    

// return the available space of stream fifo
import "BDPI" function Bit#(16) getStreamFIFOAvailability();                   
                 
(* synthesize *)
module mkStreamFIFOInstance(StreamFIFO#(`BufferSz,`SSz,Bit#(`DataSz)));
   StreamFIFO#(`BufferSz,`SSz,Bit#(`DataSz)) fifos <- mkStreamLFIFO;
   return fifos;
endmodule

// (* synthesize *)
// module mkStreamFIFOTest(Empty);
                 
module mkHWOnlyApplication (Empty);                    
   // state elements
   let fifos <- mkStreamFIFOInstance;
   Reg#(Bool)                 init <- mkReg(False);
   Reg#(Bit#(`SSz))           inSz <- mkReg(1);
   Reg#(Bit#(`SSz))          outSz <- mkReg(1);
   Reg#(Bit#(32))         clockCnt <- mkReg(0);
   
   rule initialize(!init);
      let chk_err = setStreamFIFOSize(`BufferSz);
      init <= True;
      if (chk_err) 
         begin
            $display("Error! C Golden FIFO initialization failed!");
            $finish;
         end
   endrule

   rule enqData(init && fifos.notFull(inSz));
      let rand_data = getNextData;
      Vector#(`BufferSz,Bit#(`DataSz)) enq_vec = newVector;
      for (Integer i = 0; i < `BufferSz; i = i + 1)
         enq_vec[i] = rand_data + fromInteger(i);
      let chk_enq = enqStreamFIFO(rand_data, zeroExtend(inSz));
      if (chk_enq) // error occur
         begin
            $display("Error! Try to enq %d elements to C Golden FIFO full with %d free spaces!",inSz,getStreamFIFOAvailability);
            $finish;
         end
      fifos.enq(inSz,enq_vec);
   endrule

   rule deqData(init && fifos.notEmpty(outSz));
      let data = fifos.first;
      fifos.deq(outSz);
      if (getStreamFIFOUsage < zeroExtend(outSz)) 
         begin
            $display("Error! Try to deq %d elements from C Golden FIFO with %d elements!",outSz,getStreamFIFOUsage);
            $finish;
         end
      let chk_data = deqStreamFIFO(zeroExtend(outSz));
      if (chk_data != data[0])
         begin
            $display("Error! C Golden FIFO return different data %x as Bluespec FIFO %x!",chk_data,data[0]);
            $finish;
         end
   endrule

   rule advClock(init);
      inSz <= (inSz == `MaxSSz) ? 1 : inSz + 1;
      outSz <= (outSz == 1) ? `MaxSSz : outSz - 1;
      clockCnt <= clockCnt + 1;
      if (clockCnt == `EndCycle)
         begin
            $display("Pass!");
            $finish;
         end
   endrule
   
endmodule

