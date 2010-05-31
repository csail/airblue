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

// import standard libraries
import FIFO::*;
import GetPut::*;
import Monad::*;
import Vector::*;

// import project libraries
// import DataTypes::*;
// import Interfaces::*;
// import IViterbi::*;
// import ProtocolParameters::*;
// import ViterbiParameters::*;
// import VParams::*;
// import BranchMetricUnit::*;
// import PathMetricUnit::*;
// import TracebackUnit::*;

//`include "../../../WiFiFPGA/Macros.bsv"

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/airblue_parameters.bsh"

//`define isDebug True // uncomment this line to display error
      
/////////////////////////////////////////////////////////
// Begin of Viterbi Module 

// viterbi not compatible with soft phy hints
(*synthesize*)
module mkIViterbiTBPath (IViterbi);
   
   BranchMetricUnit     bmu <- mkBranchMetricUnit;
   PathMetricUnit       pmu <- mkPathMetricUnit("PMU Viterbi",getPMUOutViterbi,getBranchMetricForward);

   `ifdef SOFT_PHY_HINTS
   SoftTracebackUnit    tbu <- mkSoftTracebackUnit();
   `else
   HardTracebackUnit    tbu <- mkHardTracebackUnit();
   `endif

   Reg#(VTBStageIdx) push_zeros_cnt_down <- mkReg(0); // no. zeros to be pushed

   //mkConnection(bmu.out, pmu.in);
   rule branchMetricTransfer;
     let branchMetric <- bmu.out.get;
     pmu.in.put(PathMetricUnitIn{branchMetric: branchMetric, initPathMetric:  initPathMetricZero()});
   endrule

   rule connectPMUTBU;
     let pmuOut <- pmu.out.get;
     tbu.in.put(pmuOut);
   endrule
   
   rule pushZeros(push_zeros_cnt_down > 0);
      Bool need_rst = push_zeros_cnt_down == 1;
      VInType v_data = tuple2(need_rst, replicate(replicate(0)));
      bmu.in.put(v_data);
      push_zeros_cnt_down <= push_zeros_cnt_down - 1;
      if(`DEBUG_CONV_DECODER == 1)
         $display("pushZeros need_rst %d", need_rst);
   endrule

   method Action putData (VInType in_data) if (push_zeros_cnt_down == 0);
      match { .rst, .data } = in_data;
      bmu.in.put(tuple2(False, data));
      if (rst)
         begin
            VTBStageIdx new_push_zeros_cnt_down;
            `ifdef SOFT_PHY_HINTS
            new_push_zeros_cnt_down = fromInteger(no_tb_stages*2);
            `else 
            new_push_zeros_cnt_down = fromInteger(no_tb_stages);
            `endif
            push_zeros_cnt_down <= new_push_zeros_cnt_down;
            if(`DEBUG_CONV_DECODER == 1)
               $display("IViterbiTBPath set push_zeros_cnt_down = %d",new_push_zeros_cnt_down);
        end
   endmethod

   method ActionValue#(VOutType) getResult();
      let res <- tbu.out.get();
      return res;
   endmethod
   
endmodule

module mkConvDecoder#(function Bool decodeBoundary(ctrl_t ctrl))
   (Viterbi#(ctrl_t,n2,n))
   provisos(Log#(n2,ln2),
            Log#(n,ln),
            Bits#(ctrl_t, ctrl_sz));

   // These may lead to death.... figure them out. Probably have to be bigger 
   // due to depth of pipeline
   Integer   bmu_latency = 3; // 2 fifos + 1 cycle
   Integer   pmu_latency = 1; // 1 cycle
   `ifdef SOFT_PHY_HINTS
   Integer   tbu_latency = no_tb_stages*2 + 1; // no. tb stages + 1 fifo cycle
   `else
   Integer   tbu_latency = no_tb_stages + 1; // no. tb stages + 1 fifo cycle
   `endif
   Integer   ctrl_q_sz = ((bmu_latency+pmu_latency+tbu_latency)/valueOf(n)) + 1;

   // IViterbi viterbi <- mkIViterbiTB;     // murali TB
   let viterbi <- mkIViterbiTBPath;         // alfred TB
   let decoder <- mkConvDecoderInstance(decodeBoundary, ctrl_q_sz, viterbi);
   return decoder;
endmodule
