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
import GetPut::*;
import Vector::*;

// import project libraries
// import Controls::*;
// import ConvEncoder::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_convolutional_encoder.bsh"


// (* synthesize *)
// module mkConvEncoderTest(Empty);
   
module mkHWOnlyApplication (Empty);   
   // constants
   Vector#(2,Bit#(7)) gen_polys = newVector;
   gen_polys[0] = 7'b1011011;
   gen_polys[1] = 7'b1111001;
      
   // state elements
   ConvEncoder#(Bit#(1),12,1,24,2) conv_encoder;
   conv_encoder <- mkConvEncoder(gen_polys);
   Reg#(Bit#(12)) data  <- mkRegU;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putInput(True);
      let mesg = Mesg{control: ?,
                      data: data};
      conv_encoder.in.put(mesg);
      data <= data + 1;
      $display("input: data: %b",data);
   endrule

   rule getOutput(True);
      let mesg <- conv_encoder.out.get;
      $display("output: data: %b",mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




