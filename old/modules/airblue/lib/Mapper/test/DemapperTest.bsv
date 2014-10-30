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
import FixedPoint::*;
import GetPut::*;
import Vector::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
// import Demapper::*;
// import Mapper::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
`include "asim/provides/airblue_mapper.bsh"
`include "asim/provides/airblue_demapper.bsh"

function t idFunc (t in);
   return in;
endfunction

(* synthesize *)
module mkDemapperInstance(Demapper#(Modulation,48,12,2,14,Bit#(3)));
   Demapper#(Modulation,48,12,2,14,Bit#(3)) demapper;
   demapper <- mkDemapper(idFunc, False);
   return demapper;
endmodule

// (* synthesize *)
// module mkDemapperTest(Empty);

module mkHWOnlyApplication(Empty);   
   // state elements
   Mapper#(Modulation,12,48,2,14) mapper <- mkMapper(idFunc, False);
   Demapper#(Modulation,48,12,2,14,Bit#(3)) demapper;
   demapper <- mkDemapperInstance();
   Reg#(Bit#(4))  ctrl  <- mkReg(1);
   Reg#(Bit#(12)) data  <- mkReg(0);
   Reg#(Bit#(8))  cntr  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putMapperNewCtrl(cntr==0);
      let newCtrl = (ctrl == 8) ? 1 : ctrl << 1;
      let newCntr = case (unpack(newCtrl))
		       BPSK:   3;    
		       QPSK:   7;
		       QAM_16: 15;
		       QAM_64: 23;
		    endcase;
      let mesg = Mesg { control: unpack(newCtrl),
	   	        data: data};
      mapper.in.put(mesg);
      ctrl <= newCtrl;
      cntr <= newCntr;
      data <= data + 1;
      $display("Mapper input: ctrl = %d, data:%b",newCtrl,data);
   endrule
   
   rule putMapperInput(cntr > 0);
      let mesg = Mesg { control: unpack(ctrl),
	   	        data: data};
      mapper.in.put(mesg);
      cntr <= cntr - 1;
      data <= data + 1;
      $display("Mapper input: ctrl = %d, data:%b",ctrl,data);
   endrule

   rule getMapperOutput(True);
      let mesg <- mapper.out.get;
      demapper.in.put(mesg);
      $display("Mapper output: ctrl = %d, data: %h",mesg.control,mesg.data);
   endrule
   
   rule getDemapperOutput(True);
      let mesg <- demapper.out.get;
      $display("Demapper output: ctrl = %d, data: %b",mesg.control,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




