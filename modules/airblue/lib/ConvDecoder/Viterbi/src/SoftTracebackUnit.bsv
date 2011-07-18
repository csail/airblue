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
import FIFOLevel::*;
import GetPut::*;
import Vector::*;
import FShow::*;


// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_shift_regs.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/provides/librl_bsv_storage.bsh"

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
   Reg#(Bool)                                 wait_rst    <- mkReg(False); // if incoming instr request a reset, we need to clear pm_delay_q first
   Reg#(Bool)                                 process_rst <- mkReg(False); // if incoming instr request a reset, we need to clear pm_delay_q first
   Reg#(Bit#(16))                             bitInCount <- mkReg(0);
   TracebackUnit                              tb         <- mkTracebackUnit();
   SoftPathDetector                           spd        <- mkSoftPathDetector();
   FIFO#(VPathMetricUnitOut)                  pm_q       <- mkSizedFIFO(2);
   FIFOCountIfc#(VPathMetricUnitOut,TAdd#(VNoTBStages,1)) pm_delay_q <- mkSizedBRAMFIFOCount();
   ShiftRegs#(TSub#(VStateSz,1),VState)       shift_reg  <- mkShiftRegs();  // crap output by the tb for the first tb_no_stages cycles                     
   
   // a rule that connect the output of the traback unit to the path detector
   rule connect_tb_2_spd(!process_rst); // this guard is sufficient, but not necessary
      let tb_state <- tb.out.get();
      shift_reg.enq(tpl_2(tb_state));
      pm_delay_q.deq();

      if(tpl_1(tb_state))
        begin
          process_rst <= True;
        end
      // Use this one in the clear case
      spd.in.put(tuple2(shift_reg.first(),tuple2(tpl_1(tb_state),tpl_2(pm_delay_q.first()))));
      if(`DEBUG_CONV_DECODER == 1)
         $display("%t SoftTracebackUnit: xfer data from traceback unit to path detector count: %d ", $time(), pm_delay_q.count());
   endrule

   // need_rst is at the tail
   // need to clear out pm fifo
   rule drain_pm_q(process_rst);         
     if(`DEBUG_CONV_DECODER == 1)
        $display("%t SoftTracebackUnit: reset coming, draining pm_delay_q with %d values", $time(),pm_delay_q.count());
    
     pm_delay_q.clear();
     wait_rst <= False;
     process_rst <= False;
     bitInCount <= 0;
   endrule

 
   rule process_pm_q(!wait_rst);
      // tb should be providing this
      if(tpl_1(pm_q.first()))
        begin
          wait_rst <= True;
        end
      bitInCount <= bitInCount + 1;
      pm_q.deq();
      tb.in.put(pm_q.first());
      pm_delay_q.enq(pm_q.first());
      if(`DEBUG_CONV_DECODER == 1)
        $display("%t SoftTracebackUnit: put data to traceback unit and pm_delay_q count: %d need_rst: %d bits %d",$time(),pm_delay_q.count(), tpl_1(pm_q.first), bitInCount+1);
   endrule
   
   interface in = fifoToPut(pm_q);   
   interface out = spd.out;
endmodule


