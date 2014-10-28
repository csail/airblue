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
`include "asim/provides/airblue_convolutional_decoder_common.bsh"

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
      
      DecisionOutType decision <- calculateDecision(in_data);
      VOutType out = create_vout(decision.res, decision.soft_phy_hints);

      out_data_q.enq(out);
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
             
      if(`DEBUG_BCJR == 1) 
        begin 
          $display("Decision Forward,Reverse Vector: ", fshow(forwardReverse)); 
          $display("Decision Forward,Reverse Vector Norm: ", fshow(forwardReverseNorm)); 
        end

      // obtain min index
      let indexA = tpl_1(fold(chooseMax,zip(genWith(fromInteger),errA)));
      let indexB = tpl_1(fold(chooseMax,zip(genWith(fromInteger),errB)));
      if(`DEBUG_BCJR == 1) 
        begin
          $display("Decision: Max Index Forward: %d (%h) and Backward: %d (%h)", indexB, errB[indexB], indexA, errA[indexA]);
        end
   
      if(`DEBUG_BCJR == 1) 
        begin
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
        end

      let combinedProbs = zipWith( \+ , map(signExtend,tpl_1(unzip(vecA))), map(signExtend,tpl_1(unzip(vecB))));
      //$display("Decision: Combined probs: ", fshow(combinedProbs));
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


