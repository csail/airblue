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
import GetPut::*;
import Interfaces::*;
import Depuncturer::*;
import Vector::*;

// test
function PuncturerCtrl mapCtrl(Bit#(3) rate);
      return case (rate)
		0: Half;
		1: TwoThird;
		2: FiveSixth;
		3: TwoThird;
		4: FiveSixth;
		5: ThreeFourth;
		6: FiveSixth;
//		7: Same;
	     endcase; // case(rate)
endfunction // Bit
   
function DepunctData#(4) p1 (DepunctData#(3) x);
   DepunctData#(4) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[2] = x[1];
   outVec[3] = x[2];
   return outVec;
endfunction // Bit
   
function DepunctData#(6) p2 (DepunctData#(4) x);
   DepunctData#(6) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[3] = x[2];
   outVec[4] = x[3];
   return outVec;
endfunction // Bit
   
function DepunctData#(10) p3 (DepunctData#(6) x);
   DepunctData#(10) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[3] = x[2];
   outVec[4] = x[3];
   outVec[7] = x[4];
   outVec[8] = x[5];
   return outVec;
endfunction // Bit
      
(* synthesize *)
module mkWiMaxDepuncturer (Depuncturer#(Bit#(3),8,8,24,24));

   function DepunctData#(8) pp1(DepunctData#(6) x);
      return parDepunctFunc(p1,x);
   endfunction
   
   function DepunctData#(12) pp2(DepunctData#(8) x);
      return parDepunctFunc(p2,x);
   endfunction
   
   function DepunctData#(10) pp3(DepunctData#(6) x);
      return parDepunctFunc(p3,x);
   endfunction
   
   Depuncturer#(Bit#(3),8,8,24,24) depuncturer;
   depuncturer <- mkDepuncturer(mapCtrl,pp1,pp2,pp3);
   return depuncturer;
   
endmodule

(* synthesize *)
module mkDepuncturerTest (Empty);

   Depuncturer#(Bit#(3),8,8,24,24) depuncturer <- mkWiMaxDepuncturer;
   Reg#(Bit#(3)) rate <- mkReg(0);
   Reg#(Bit#(3)) counter <- mkReg(0);
   Reg#(DepunctData#(8)) inData <- mkReg(replicate(0));
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putNewRate(counter == 0);
      let newRate = (rate == 6) ? 0 : rate + 1;
      let newData = inData;
      let newMesg = Mesg { control: newRate,
			   data: newData};
      Bit#(3) newCounter = case (newRate)
			      0: 0;
			      1: 2;
			      2: 2;
			      3: 2;
			      4: 2;
			      5: 5;
			      6: 2;
			   endcase;
      rate <= newRate;
      inData <= newData;
      counter <= newCounter;
      depuncturer.in.put(newMesg);
      $display("In Mesg: ctrl: %d,  data: %b, counter:%d",newMesg.control,newMesg.data,newCounter);
   endrule

   rule putNewData(counter > 0);
      let newRate = rate;
      let newData = inData;
      let newMesg = Mesg { control: newRate,
			   data: newData};
      inData <= newData;
      counter <= counter - 1;
      depuncturer.in.put(newMesg);
      $display("In Mesg: ctrl: %d,  data: %b, counter:%d",newMesg.control,newMesg.data,counter - 1);
   endrule
   
   rule getData(True);
      let outMesg <- depuncturer.out.get;
      $display("Out Mesg: ctrl: %d,  data: %b",outMesg.control,outMesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 10000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
   
endmodule
   
   




