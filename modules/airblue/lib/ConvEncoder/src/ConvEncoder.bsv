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

/////////////////////////////////////////////////////////////////////////
// Importing Libraries

// import standard libraries
import FIFO::*;
import GetPut::*;
import Vector::*;

// import project libraries
// import DataTypes::*;
// import Interfaces::*;
// import LibraryFunctions::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

/////////////////////////////////////////////////////////////////////////
// Definitions of Auxiliary Functions

// given the current state and the new shift in bits, give me the new state
function Bit#(kSz) getNextState(Bit#(kSz) state, Bit#(convInSz) in_bits)
   provisos (Add#(convInSz,kSz,xxA),
             Add#(kSz,convInSz,xxA));
  Bit#(xxA) tmp = {in_bits, state};
  return tpl_1(split(tmp)); // drop LSBs
endfunction

/////////////////////////////////////////////////////////////////////////
// Definitions of the Main Module

// implementation of the convolutional encoder
module mkConvEncoder#(Vector#(polyNo,Bit#(kSz)) gen_polys) // generator polynomial as parameter
   (ConvEncoder#(ctrlT,inSz,convInSz,outSz,convOutSz))
   provisos (Add#(1,xxA,inSz),
             Add#(1,kSzMinus1,kSz),
             Add#(1,xxB,inNo),
             Add#(convInSz,kSz,xxC),
             Add#(kSz,convInSz,xxC),
             Mul#(inNo,convInSz,inSz),
	     Mul#(inNo,convOutSz,outSz),
	     Bits#(ctrlT,ctrlSz));
   
   // constants
   Integer conv_out_sz = valueOf(convOutSz);
   Integer out_sz = valueOf(outSz);
   
   // state elements
   FIFO#(EncoderMesg#(ctrlT,inSz))  in_q     <- mkLFIFO;
   FIFO#(EncoderMesg#(ctrlT,outSz)) out_q    <- mkLFIFO;
   Reg#(Bit#(kSz))                  hist_val <- mkReg(0);
   
   // rules
   rule compute(True);
      EncoderMesg#(ctrlT,inSz)                 mesg         = in_q.first;
      Vector#(inNo,Bit#(convInSz))             in_data      = unpack(mesg.data);
      Vector#(inNo,Bit#(kSz))                  hist_val_vec = sscanl(getNextState,hist_val,in_data); // generate the sequence states that will generate the output
      Vector#(convOutSz,Vector#(inNo,Bit#(1))) out_vec      = newVector;
      Vector#(outSz,Bit#(1))                   out_data_vec = newVector;
      for (Integer i = 0; i < conv_out_sz; i = i + 1)
         out_vec[i] = map(genXORFeedback(gen_polys[i]),hist_val_vec); // generate output with LFSR
      for (Integer i = 0; i < out_sz; i = i + 1)
         out_data_vec[i] = out_vec[i%conv_out_sz][i/conv_out_sz]; // put the output at the right order
      Bit#(outSz) out_data = pack(out_data_vec);
      in_q.deq;
      hist_val <= last(hist_val_vec);
      out_q.enq(Mesg{control: mesg.control,
                     data: out_data});
   endrule
   
   //methods
   interface in = fifoToPut(in_q);
   interface out = fifoToGet(out_q);
endmodule
