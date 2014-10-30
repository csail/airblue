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
// import Interleaver::*;
// import Mapper::*;
// import Demapper::*;

// Local includes
import AirblueTypes::*;
import AirblueCommon::*;
`include "asim/provides/airblue_interleaver.bsh"
`include "asim/provides/airblue_deinterleaver.bsh"
`include "asim/provides/airblue_mapper.bsh"
`include "asim/provides/airblue_demapper.bsh"

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

function Integer deinterleaverGetIndex(Modulation m, Integer j);
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
   Integer f = (j/s);
   Integer i = s*f + (j + (12*j/ncbps))%s;
   Integer k = 12*i-(ncbps-1)*(12*i/ncbps);
   return (j >= ncbps) ? j : k;
endfunction			  

(* synthesize *)
module mkInterleaverInstance(Interleaver#(Modulation,24,24,192));
   Interleaver#(Modulation,24,24,192) interleaver;
   interleaver <- mkInterleaver(idFunc,interleaverGetIndex);
   return interleaver;
endmodule

(* synthesize *)
module mkDeinterleaverInstance(Deinterleaver#(Modulation,24,24,ViterbiMetric,192));
   Deinterleaver#(Modulation,24,24,ViterbiMetric,192) deinterleaver;
   deinterleaver <- mkDeinterleaver(idFunc,deinterleaverGetIndex);
   return deinterleaver;
endmodule

// (* synthesize *)
// module mkDeinterleaverTest(Empty);
   
module mkHWOnlyApplication (Empty);
   // state elements
   Interleaver#(Modulation,24,24,192) interleaver;
   interleaver <- mkInterleaverInstance;
   Deinterleaver#(Modulation,24,24,ViterbiMetric,192) deinterleaver;
   deinterleaver <- mkDeinterleaverInstance;
   Mapper#(Modulation,24,48,2,14) mapper <- mkMapper(idFunc, True);
   Demapper#(Modulation,48,24,2,14,ViterbiMetric) demapper;
   demapper <- mkDemapper(idFunc, True);
   Reg#(Bit#(4))  ctrl  <- mkReg(1);
   Reg#(Bit#(24)) data  <- mkReg(0);
   Reg#(Bit#(8))  cntr  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putInterleaverNewCtrl(cntr==0);
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
      $display("Interleaver input: ctrl = %d, data:%b",newCtrl,data);
   endrule
   
   rule putInterleaverInput(cntr > 0);
      let mesg = Mesg { control: unpack(ctrl),
	   	        data: data};
      interleaver.in.put(mesg);
      cntr <= cntr - 1;
      data <= data + 1;
      $display("Interleaver input: ctrl = %d, data:%b",ctrl,data);
   endrule

   rule getInterleaverOutput(True);
      let mesg <- interleaver.out.get;
      mapper.in.put(mesg);
      $display("Interleaver output: ctrl = %d, data: %b",mesg.control,mesg.data);
   endrule
   
   rule getMapperOutput(True);
      let mesg <- mapper.out.get;
      demapper.in.put(mesg);
      $display("Mapper output: ctrl = %d, data: %h",mesg.control,mesg.data);
   endrule
   
   rule getDemapperOutput(True);
      let mesg <- demapper.out.get;
      deinterleaver.in.put(mesg);
      $display("Demapper output: ctrl = %d, data: %b",mesg.control,mesg.data);
   endrule
   
   rule getDeinterleaverOutput(True);
      let mesg <- deinterleaver.out.get;
      $display("Deinterleaver output: ctrl = %d, data: %b",mesg.control,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




