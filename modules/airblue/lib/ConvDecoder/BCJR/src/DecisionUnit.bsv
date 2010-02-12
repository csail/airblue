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

// import project libraries
// import ProtocolParameters::*;
// import ViterbiParameters::*;
// import VParams::*;

// `include "../../../WiFiFPGA/Macros.bsv"

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_convolutional_decoder.bsh"

//`define isDebug True // uncomment this line to display error

typedef Bit#(TAdd#(0,SizeOf#(VPathMetric))) ExtendedPathMetric;

/////////////////////////////////////////////////////////////////////////
// Definition of TracebackUnit Interface and usefule types

interface DecisionUnit;
   method Put#(Tuple2#(VPathMetricUnitOut,VPathMetricUnitOut))  in;
   method Get#(VOutType) out;
endinterface

/////////////////////////////////////////////////////////////////////////
// Definitions of Auxiliary Functions

// choose the larger of the two
function Tuple2#(ctrl_t, comp_t) chooseMax (Tuple2#(ctrl_t, comp_t) in1, 
                                            Tuple2#(ctrl_t, comp_t) in2)
  provisos
  (Arith#(comp_t), Literal#(comp_t),
   Bits#(comp_t, comp_t_sz), Ord#(comp_t),
   Add#(1, a__, comp_t_sz));
  
 // let diff = tpl_2(in1) - tpl_2(in2); 
 // return (diff  < 0) ? in2 : in1;
 return ((tpl_2(in1) - tpl_2(in2)) < unpack({1'b1,0})) ? in1 : in2;
endfunction // Tuple2


function Tuple2#(ctrl_t, comp_t) chooseMin (Tuple2#(ctrl_t, comp_t) in1, 
                                            Tuple2#(ctrl_t, comp_t) in2)
  provisos
  (Arith#(comp_t), Literal#(comp_t),
   Bits#(comp_t, comp_t_sz), Ord#(comp_t));
  
  let diff = tpl_2(in1) - tpl_2(in2); 
  return (diff  < 0) ? in1 : in2;
endfunction // Tuple2

function Bit#(asz) getMSBs (Bit#(bsz) in_data)
   provisos (Add#(asz,xxA,bsz));
   return tpl_1(split(in_data));
endfunction

function VState getPathMetricMaxIndex(VPathMetricUnitOut metricA);
  let vecA = tpl_2(metricA);
  let errA = tpl_1(unzip(vecA));
  return  tpl_1(fold(chooseMax,zip(genWith(fromInteger),errA)));
endfunction

/////////////////////////////////////////////////////////////////////////
// Implementation of TracebackUnit

(* synthesize *)
module mkDecisionUnit (DecisionUnit);

  
   FIFO#(VOutType)                                 out_data_q <- mkSizedFIFO(2);
   FIFO#(Vector#(VTotalStates,ExtendedPathMetric)) combinedQ  <- mkLFIFO;
   
   rule computeTree;
      let                               in_data          = combinedQ.first;
      combinedQ.deq;

      Vector#(VTotalStates,Tuple2#(VState,ExtendedPathMetric)) path_metric_sums = zip(genWith(fromInteger), in_data);
      Tuple2#(VState,ExtendedPathMetric)                       min_tpl          = fold(chooseMax, path_metric_sums);
      VState                                                   min_idx          = tpl_1(min_tpl);
      ExtendedPathMetric                                       min_path_metric  = tpl_2(min_tpl);
      Vector#(FwdSteps,Bit#(ConvInSz))                         res              = unpack(pack(truncateLSB(min_idx)));
      Vector#(TDiv#(VTotalStates,2),Tuple2#(VState,ExtendedPathMetric)) zero_sums = take(path_metric_sums);
      Vector#(TDiv#(VTotalStates,2),Tuple2#(VState,ExtendedPathMetric)) one_sums = takeTail(path_metric_sums);

      let                                other_path_metric_sums = (pack(res) == {1'b1} ? zero_sums : one_sums);
      Tuple2#(VState,ExtendedPathMetric) other_min_tpl = fold(chooseMax, other_path_metric_sums);
      VState                             other_min_idx = tpl_1(other_min_tpl);
      ExtendedPathMetric                 other_min_path_metric = tpl_2(other_min_tpl);
      ExtendedPathMetric                 soft_phy_hints = min_path_metric - other_min_path_metric;
      
      `ifdef SOFT_PHY_HINTS
      let out = tuple2(res,soft_phy_hints);
      `else
      let out = res;
      `endif

      $display("path_metric_sums: ", fshow(path_metric_sums));
      $display("other_path_metric_sums: ", fshow(other_path_metric_sums));
      $display("zero_sums: ", fshow(zero_sums));
      $display("one_sums: ", fshow(one_sums));

      $display("Decision Unit Max : %d (%h, check %h) Bit out: %h Other bit: %d (%h, check %h), hints (diff of two bits) %h", min_idx, min_path_metric, tpl_2(path_metric_sums[min_idx]), res, 
               other_min_idx, other_min_path_metric, tpl_2(path_metric_sums[other_min_idx]),soft_phy_hints);
         out_data_q.enq(out);
               `ifdef isDebug
               $display("TBU min_idx %d out_q.enq %d need_rst %d",min_idx,res, need_rst);
               `endif

   endrule

   interface Put in;
   // If the two decision bits are not the same, we may want to choose another option
   method Action put(Tuple2#(VPathMetricUnitOut,VPathMetricUnitOut) in_tup);
      match{.metricA, .metricB} = in_tup;   
      let vecA = tpl_2(metricA);
      let vecB = tpl_2(metricB);
      let errA = tpl_1(unzip(vecA));
      let errB = tpl_1(unzip(vecB));
   
      let forwardReverse = zip(errB,errA);
      let errAmin = errA[tpl_1(fold(chooseMin,zip(genWith(fromInteger),errB)))];
      let errBmin = errB[tpl_1(fold(chooseMin,zip(genWith(fromInteger),errB)))];
      let forwardReverseNorm = zip(
	 zipWith( \- ,errA, replicate(errAmin)),
	 zipWith( \- ,errB, replicate(errBmin))
	 );

      // Show the vectors:
      $display("Decision Forward,Reverse Vector: ", fshow(forwardReverse)); 
      $display("Decision Forward,Reverse Vector Norm: ", fshow(forwardReverseNorm)); 
      // obtain min index
      let indexA = tpl_1(fold(chooseMax,zip(genWith(fromInteger),errA)));
      let indexB = tpl_1(fold(chooseMax,zip(genWith(fromInteger),errB)));
      $display("Decision: Max Index Forward: %d (%h) and Backward: %d (%h)", indexB, errB[indexB], indexA, errA[indexA]);
   
      if(tpl_1(metricA) != tpl_1(metricB))
         begin
            $display("Forward: %h and Backward: %h last do not match", tpl_1(metricB),tpl_1(metricA));
         end
      if(tpl_1(metricA))
         begin
            $display("Decision Unit Backwards last");
         end 
      if(tpl_1(metricB))
         begin
            $display("Decision Unit Backwards last");
         end 
      let combinedProbs = zipWith( \+ , map(signExtend,tpl_1(unzip(vecA))), map(signExtend,tpl_1(unzip(vecB))));
      $display("Decision: Combined probs: ", fshow(combinedProbs));
        combinedQ.enq(combinedProbs);
      endmethod
   endinterface                
   
   interface Get out;
      method ActionValue#(VOutType) get();
         out_data_q.deq;
         return out_data_q.first;
      endmethod
   endinterface
endmodule


