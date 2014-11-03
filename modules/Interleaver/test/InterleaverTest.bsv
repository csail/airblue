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

import GetPut::*;
import Vector::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
import Interleaver::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;

function t idFunc (t in);
   return in;
endfunction

function Integer interleaverGetIndex(Modulation m, Integer k);
    Integer s = 1;  
    Integer ncbps = 192;
    case (m)
      BPSK:  
	begin
	   ncbps = 192;
	   s = 1;
	end
      QPSK:  
	begin
	   ncbps = 384;
	   s = 1;
	end
      QAM_16:
	begin
	   ncbps = 768;
	   s = 2;
	end
      QAM_64:
	begin
	   ncbps = 1152;
	   s = 3;
	end
    endcase // case(m)
    Integer i = (ncbps/12) * (k%12) + k/12;
    Integer f = (i/s);
    Integer j = s*f + (i + ncbps - (12*i/ncbps))%s;
    return (k >= ncbps) ? k : j;
endfunction			  

// (* synthesize *)
// module mkInterleaverTest(Empty);
   
module mkHWOnlyApplication (Empty);
   // state elements
   Interleaver#(Modulation,24,24,192) interleaver;
   interleaver <- mkInterleaver(idFunc, interleaverGetIndex);
   Reg#(Bit#(4))  ctrl  <- mkReg(1);
   Reg#(Bit#(24)) data  <- mkReg(?);
   Reg#(Bit#(8))  cntr  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putNewCtrl(cntr==0);
      let newCtrl = (ctrl == 8) ? 1 : ctrl << 1;
      let newCntr = case (unpack(newCtrl))
		       BPSK:   7;
		       QPSK:   15;
		       QAM_16: 31;
		       QAM_64: 47;
		    endcase;
      let mesg = Mesg { control: unpack(newCtrl),
	   	        data: data};
      interleaver.in.put(mesg);
      ctrl <= newCtrl;
      cntr <= newCntr;
      data <= data + 1;
      $display("input: ctrl = %d, data:%h",newCtrl,data);
   endrule
   
   rule putInput(cntr > 0);
      let mesg = Mesg { control: unpack(ctrl),
	   	        data: data};
      interleaver.in.put(mesg);
      cntr <= cntr - 1;
      data <= data + 1;
      $display("input: ctrl = %d, data:%h",ctrl,data);
   endrule

   rule getOutput(True);
      let mesg <- interleaver.out.get;
      $display("output: ctrl = %d, data: %h",mesg.control,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




