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
   
   BranchMetricUnit bmu <- mkBranchMetricUnit;
   PathMetricUnit   pmu <- mkPathMetricUnit("PMU Viterbi",getPMUOutViterbi,getBranchMetricForward);
   TracebackUnit    tbu <- mkTracebackUnit;
   
   //mkConnection(bmu.out, pmu.in);
   rule branchMetricTransfer;
     let branchMetric <- bmu.out.get;
     pmu.in.put(PathMetricUnitIn{branchMetric: branchMetric, initPathMetric:  initPathMetricZero()});
   endrule

   rule connectPMUTBU;
     let pmuOut <- pmu.out.get;
     tbu.in.put(pmuOut);
   endrule
   
   method Action putData (VInType in_data);
      bmu.in.put(in_data);
   endmethod

   method ActionValue#(VOutType) getResult();
      let res <- tbu.out.get();
      return res;
   endmethod
   
endmodule

// module mkViterbi (Viterbi#(ctrl_t,n2,n))
module mkViterbi#(function Bool needPushZeros(ctrl_t ctrl)) (Viterbi#(ctrl_t,n2,n))
   provisos(Log#(n2,ln2),
	    Log#(n,ln),
	    Bits#(ctrl_t, ctrl_sz));
   
   // constants
   // n must be multiple of fwd_steps * conv_in_sz
   Bit#(ln)  check_n   = fromInteger(valueOf(n)-(fwd_steps * conv_in_sz));
   // n must be multiple of fwd_steps * conv_out_sz
   Bit#(ln2) check_n2  = fromInteger(valueOf(n2)-(fwd_steps * conv_out_sz));
   Integer   bmu_latency = 3; // 2 fifos + 1 cycle
   Integer   pmu_latency = 1; // 1 cycle
   Integer   tbu_latency = no_tb_stages + 1; // no. tb stages + 1 fifo cycle
   Integer   ctrl_q_sz = ((bmu_latency+pmu_latency+tbu_latency)/valueOf(n)) + 1; 
   
   // state elements
//   IViterbi viterbi <- mkIViterbiTB;     // murali TB
   IViterbi viterbi <- mkIViterbiTBPath;   // alfred TB
   FIFO#(DecoderMesg#(ctrl_t,n2,ViterbiMetric)) in_q <- mkLFIFO;
   Reg#(Bit#(ln2)) in_data_count <- mkReg(0);
   Reg#(Vector#(n,ViterbiOutput)) out_data <- mkReg(newVector);
   Reg#(Bit#(ln)) out_data_count <- mkReg(0);
   FIFO#(DecoderMesg#(ctrl_t,n,ViterbiOutput)) out_q <- mkSizedFIFO(2);
   FIFO#(ctrl_t) ctrl_q <- mkSizedFIFO(ctrl_q_sz);
   Reg#(VTBStageIdx) push_zeros_cnt_down <- mkReg(0); // no. zeros to be pushed

   rule pushDataToViterbi (push_zeros_cnt_down == 0);
      DecoderMesg#(ctrl_t,n2,ViterbiMetric) in_mesg = in_q.first;
      ctrl_t in_ctrl = in_mesg.control;
      Vector#(n2,ViterbiMetric) in_data = in_mesg.data;
      Vector#(FwdSteps,Vector#(ConvOutSz, VMetric)) v_data = newVector;
      for (Integer i = 0; i < fwd_steps; i = i + 1)
	 begin
	    for (Integer j = 0; j < conv_out_sz; j = j + 1)
	       begin
		  let offset = i * conv_out_sz + j;
 		  v_data[i][j] = in_data[in_data_count + fromInteger(offset)];
	       end
	 end
      viterbi.putData(tuple2(False,v_data));
      if (in_data_count == check_n2) // last
         begin
            in_q.deq;
            in_data_count <= 0;
            ctrl_q.enq(in_ctrl);
            if (needPushZeros(in_ctrl)) // need to push zeros to drive data out
               push_zeros_cnt_down <= fromInteger(no_tb_stages);
         end
      else
         in_data_count <= in_data_count + fromInteger(fwd_steps * conv_out_sz);
      `ifdef isDebug
      $display("pushDataToViterbi");
      `endif 
   endrule
   
   rule pushZerosToViterbi (push_zeros_cnt_down > 0);
      Bool need_rst = push_zeros_cnt_down == 1;
      VInType v_data = tuple2(need_rst, replicate(replicate(0)));
      viterbi.putData(v_data);
      push_zeros_cnt_down <= push_zeros_cnt_down - 1;
      `ifdef isDebug
      $display("pushZerosToViterbi need_rst %d",need_rst);
      `endif 
   endrule

   // Change to shift at some point?
   rule pullDataFromViterbi (True);
      `ifdef SOFT_PHY_HINTS
      VOutType v_data_tpl <- viterbi.getResult();
      let v_data      = tpl_1(v_data_tpl);
      let v_data_soft = tpl_2(v_data_tpl);
      `else
      VOutType v_data <- viterbi.getResult();
      `endif
      Vector#(n,ViterbiOutput) new_out_data = out_data;
      for (Integer i = 0 ; i < fwd_steps; i = i + 1)
	 begin
            for (Integer j = 0; j < conv_in_sz; j = j + 1)
               begin
                  let offset = i * conv_in_sz + j;
                  `ifdef SOFT_PHY_HINTS
	          new_out_data[out_data_count+fromInteger(offset)] = tuple2(v_data[i][j],v_data_soft); 
                  `else
	          new_out_data[out_data_count+fromInteger(offset)] = v_data[i][j]; 
                  `endif
               end
	 end
      out_data <= new_out_data;
      if (out_data_count == check_n) // last
         begin
	    $display("Viterbi out data: %h", new_out_data);
            out_q.enq(Mesg{control:ctrl_q.first, data:new_out_data});
            out_data_count <= 0;
            ctrl_q.deq;
         end
      else
         begin
            out_data_count <= out_data_count + fromInteger(fwd_steps * conv_in_sz);
         end
      `ifdef isDebug
      $display("pullDataFromViterbi");
      `endif
   endrule

   interface in  = fifoToPut(in_q);
   interface out = fifoToGet(out_q); 

endmodule
