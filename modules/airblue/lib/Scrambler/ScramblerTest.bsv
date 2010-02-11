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

import Controls::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import Scrambler::*;

function t idFunc(t in);
   return in;
endfunction

(* synthesize *)
module mkScramblerTest(Empty);
   
   // state elements
   Scrambler#(ScramblerCtrl#(12,7),ScramblerCtrl#(12,7),12,12) scrambler;
   scrambler <- mkScrambler(idFunc,idFunc,7'b1001000);
   Reg#(Bit#(12)) data  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putInput(True);
      let mesg = Mesg { control: ScramblerCtrl
		       {bypass: 0,
			seed: (data[4:0] == 0) ? tagged Valid 127 : Invalid},
	   	        data: data};
      scrambler.in.put(mesg);
      data <= data + 1;
      $display("input: data: %b",data);
   endrule

   rule getOutput(True);
      let mesg <- scrambler.out.get;
      $display("output: data: %b",mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
       begin
         $display("PASS");
	 $finish;
       end
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




