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
import CPInsert::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import WiMAXPreambles::*;
import Vector::*;

function t idFunc (t in);
   return in;
endfunction

(* synthesize *)
module mkCPInsertTest(Empty);
   
   // constants
   Symbol#(256,1,15) inSymbol = newVector;
   for(Integer i = 0; i < 256; i = i + 1)
      inSymbol[i] = unpack(pack(fromInteger(i)));
   
   // state elements
   CPInsert#(CPInsertCtrl,256,1,15) cpInsert; 
   cpInsert <- mkCPInsert(idFunc,
			  getShortPreambles,
			  getLongPreambles);
   Reg#(Bit#(4)) cpsz <- mkReg(1);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putInput(True);
      CPInsertCtrl ctrl = (cpsz == 1) ? 
			  tuple2(SendLong, unpack(cpsz)) :
                          tuple2(SendNone, unpack(cpsz));
      let mesg = Mesg { control:ctrl,
	   	        data: inSymbol};
      cpInsert.in.put(mesg);
      cpsz <= (cpsz == 8) ? 1: cpsz << 1;
      $display("input: cpsize = %d",cpsz);
//      joinActions(map(fpcmplxWrite(4),inSymbol));
   endrule
   
   rule getOutput(True);
      let mesg <- cpInsert.out.get;
      $display("output: %d",mesg);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule



