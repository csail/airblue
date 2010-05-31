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

//////////////////////////////////////////////////////////////////////////
// Import Libraries

// import standard libraries
import FIFO::*;
import GetPut::*;
import Vector::*;
import FShow::*;


// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_shift_regs.bsh"

/////////////////////////////////////////////////////////////////////////
// Definition of TracebackUnit Interface and usefule types

interface SoftTracebackUnit;
   method Put#(VPathMetricUnitOut)  in;
   method Get#(VSoftOut)            out;
endinterface


/////////////////////////////////////////////////////////////////////////
// Implementation of TracebackUnit

(* synthesize *)
module mkSoftTracebackUnit (SoftTracebackUnit);

   // states
   Reg#(Bool)                                 wait_rst   <- mkReg(True); // if incoming instr request a reset, we need to clear pm_delay_q first
   TracebackUnit                              tb         <- mkTracebackUnit();
   SoftPathDetector                           spd        <- mkSoftPathDetector();
   FIFO#(VPathMetricUnitOut)                  pm_q       <- mkSizedFIFO(2);
   FIFO#(VPathMetricUnitOut)                  pm_delay_q <- mkSizedFIFO(no_tb_stages + 1);
   ShiftRegs#(TSub#(VStateSz,1),VState)       shift_reg  <- mkShiftRegs();                       
   
   // a rule that connect the output of the traback unit to the path detector
   rule connect_tb_2_spd(True);
      let tb_state <- tb.out.get();
      shift_reg.enq(tb_state);
      pm_delay_q.deq();
      spd.in.put(tuple2(shift_reg.first(),pm_delay_q.first()));
      if(`DEBUG_CONV_DECODER == 1)
         $display("SoftTracebackUnit: xfer data from traceback unit to path detector");
   endrule
   
   rule process_pm_q(True);
      if (tpl_1(pm_q.first()) && wait_rst)
         begin
            pm_delay_q.clear();
            wait_rst <= False;
            if(`DEBUG_CONV_DECODER == 1)
               $display("SoftTracebackUnit: reset due to end of packet, clear pm_delay_q");
         end
      else
         begin
            pm_q.deq();
            tb.in.put(pm_q.first());
            pm_delay_q.enq(pm_q.first());
            wait_rst <= True;
            if(`DEBUG_CONV_DECODER == 1)
               $display("SoftTracebackUnit: put data to traceback unit and pm_delay_q");
         end
   endrule
   
   interface in = fifoToPut(pm_q);   
   interface out = spd.out;
endmodule


