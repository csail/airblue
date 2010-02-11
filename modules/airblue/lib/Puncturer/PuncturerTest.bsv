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
import Puncturer::*;

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
   
function Bit#(3) p1 (Bit#(4) x);
      return {x[3:2],x[0]};
endfunction // Bit
   
function Bit#(4) p2 (Bit#(6) x);
      return {x[4:3],x[1:0]};
   endfunction // Bit
   
function Bit#(6) p3 (Bit#(10) x);
      return {x[8:7],{x[4:3],x[1:0]}};
endfunction // Bit
      
module mkWiMaxPuncturer (Puncturer#(Bit#(3),8,8,24,24));

   Bit#(2) f1_sz = 0;
   Bit#(2) f2_sz = 0;
   Bit#(1) f3_sz = 0;
   
   Puncturer#(Bit#(3),8,8,24,24) puncturer;
   puncturer <- mkPuncturer(mapCtrl,
			    parFunc(f1_sz,p1),
			    parFunc(f2_sz,p2),
			    parFunc(f3_sz,p3));
   return puncturer;
   
endmodule
   
(* synthesize *)
module mkPuncturerTest (Empty);

   Puncturer#(Bit#(3),8,8,24,24) puncturer <- mkWiMaxPuncturer;
   Reg#(Bit#(3)) rate <- mkReg(0);
   Reg#(Bit#(3)) counter <- mkReg(0);
   Reg#(Bit#(8)) inData <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putNewRate(counter == 0);
      let newRate = (rate == 6) ? 0 : rate + 1;
      let newData = inData + 1;
      let newMesg = Mesg { control: newRate,
			   data: newData};
      Bit#(3) newCounter = case (newRate)
			      0: 3;
			      1: 3;
			      2: 4;
			      3: 3;
			      4: 4;
			      5: 5;
			      6: 4;
			   endcase;
      rate <= newRate;
      inData <= newData;
      counter <= newCounter;
      puncturer.in.put(newMesg);
      $display("In Mesg: ctrl: %d,  data: %b, counter:%d",newMesg.control,newMesg.data,newCounter);
   endrule

   rule putNewData(counter > 0);
      let newRate = rate;
      let newData = inData + 1;
      let newMesg = Mesg { control: newRate,
			   data: newData};
      inData <= newData;
      counter <= counter - 1;
      puncturer.in.put(newMesg);
      $display("In Mesg: ctrl: %d,  data: %b, counter:%d",newMesg.control,newMesg.data,counter - 1);
   endrule
   
   rule getData(True);
      let outMesg <- puncturer.out.get;
      $display("Out Mesg: ctrl: %d,  data: %b",outMesg.control,outMesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 10000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
   
endmodule
   
   
   




