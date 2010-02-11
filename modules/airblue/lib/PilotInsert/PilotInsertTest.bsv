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

import Complex::*;
import Controls::*;
import DataTypes::*;
import GetPut::*;
import Interfaces::*;
import LibraryFunctions::*;
import PilotInsert::*;
import Vector::*;

function t idFunc (t in);
   return in;
endfunction

function Symbol#(64,2,14) pilotAdder(Symbol#(48,2,14) x, 
				     Bit#(1) ppv);
   
   Integer i =0, j = 0;
   // assume all guards initially
   Symbol#(64,2,14) syms = replicate(cmplx(0,0));
   
   // data subcarriers
   for(i = 6; i < 11; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 12; i < 25; i = i + 1, j = j + 1)
      syms[i] = x[j]; 
   for(i = 26; i < 32 ; i = i + 1, j = j + 1)
      syms[i] = x[j];  
   for(i = 33; i < 39 ; i = i + 1, j = j + 1)
      syms[i] = x[j];   
   for(i = 40; i < 53 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 54; i < 59 ; i = i + 1, j = j + 1)
      syms[i] = x[j];

   //pilot subcarriers
   syms[11] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[25] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[39] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[53] = mapBPSK(True,  ppv); // map 0 to -1, 1 to 1
   
   return syms;
endfunction

(* synthesize *)
module mkWiFiPilotInsertTest(Empty);
   
   PilotInsert#(PilotInsertCtrl,48,64,2,14) pilotInsert;
   pilotInsert <- mkPilotInsert(idFunc,
				pilotAdder,
				7'b1001000,
				7'b1111111);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putIntput(True);
      let iMesg = Mesg{ control: (cycle[2:0] == 0) ? 
				 PilotRst : 
		                 PilotNorm,
			data: replicate(cmplx(1,1))};
      pilotInsert.in.put(iMesg);
//      $display("Input: %h",iMesg.data);
   endrule
  
   rule getOutput(True);
      let oMesg <- pilotInsert.out.get;
      $display("Output: %h",oMesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
   
endmodule



