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
// import EHRReg::*;
// import LibraryFunctions::*;
// import ProtocolParameters::*;
// import ViterbiParameters::*;
// import VParams::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"

//`define isDebug True // uncomment this line to display error

//`define softOut True // comment this line if soft output viterbi is not needed 

/////////////////////////////////////////////////////////////////////////
// Definition of ACS Interface

//interface PathMetricUnit;
//   method Put#(PathMetricUnitIn) in;
//   method Get#(VPathMetricUnitOut)   out;
//endinterface



/////////////////////////////////////////////////////////////////////////
// Definitions of Auxiliary Functions

// init path metric, instead of making every state with same init probability
// now favour state 0 which is known to be init state of the conv encoder
// other states values are adjust to reflect its distance from the state 0
//function Vector#(VTotalStates, VPathMetric) initPathMetricZero();
//   Vector#(1,VPathMetric) first   = replicate(10);
//  Vector#(VTotalStates,VPathMetric) out_vec = append(first,replicate(0));
//   return out_vec;
//endfunction

/////////////////////////////////////////////////////////////////////////
// Implementation of PathMetricUnit

module mkPathMetricUnitGamma#(String str, 
                              function Tuple2#(Vector#(VTotalStates,VACSEntry),
                                               Vector#(VTotalStates,VACSEntry)) getPMUOut
                              (Vector#(VTotalStates, VPathMetric) path_metric,
                               Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric_forward,
                               Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric_backward),
                              function  Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric))
                              getBranchMetricForward(Vector#(VNoBranchMetric,VBranchMetric) branch_metric),
                              function  Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric))
                              getBranchMetricBackward(Vector#(VNoBranchMetric,VBranchMetric) branch_metric)
                              )
      (PathMetricUnit);
   
   Reg#(VPathMetricUnitOut) pmu_out  <- mkReg(tuple2(True,?));// This may hurt us in the long run, but we assume here  
                                                              // That the first incoming token will have the proper reset
                                                              // values
   
   Reg#(VPathMetricUnitOut) pmu_out_gamma  <- mkReg(tuple2(True,?));// This may hurt us in the long run, but we assume here  

   EHRReg#(2,Bool)          can_read <- mkEHRReg(False);      

   Reg#(Bit#(32)) dataIn  <- mkReg(0);
   Reg#(Bit#(32)) dataOut <- mkReg(0); 

   interface Put in;
      method Action put(PathMetricUnitIn pmu_in) if (!can_read[1]); // only accept new data if it is consumed
         let bmu_out = pmu_in.branchMetric;
         let initPathMetric = pmu_in.initPathMetric;
         Bool need_rst = tpl_1(pmu_out);                                       
         Bool new_need_rst = tpl_1(bmu_out);                                   
         Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric_forward = getBranchMetricForward(tpl_2(bmu_out));
         Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric_backward = getBranchMetricBackward(tpl_2(bmu_out));

      

	 if(need_rst && (`DEBUG_CONV_DECODER == 1)) 
           begin
             $display("%s resets with ", str,  fshow(initPathMetric)); 
           end

         dataIn <= dataIn + 1;

                                                     
         Vector#(VTotalStates,VPathMetric) path_metric = need_rst ? initPathMetric : tpl_1(unzip(tpl_2(pmu_out))); 
         let pmuVectors = getPMUOut(path_metric, branch_metric_forward, branch_metric_backward);
         $display("PMU Gamma");      

         pmu_out <= tuple2(new_need_rst,tpl_1(pmuVectors));
         pmu_out_gamma <= tuple2(new_need_rst,tpl_2(pmuVectors));
         can_read[1] <= True;

         //if(`DEBUG_CONV_DECODER == 1)
           //begin
             $display(" %s fires in at %t", str, $time);
             $display("%s dataIn: ", str, dataIn + 1);   
             for (Integer i = 0; i < no_states; i = i + 1)
               begin
                 for (Integer j = 0; j < radix_sz; j = j + 1)
                   begin
                     $display("PMUGamma %s state %d radix_in %d branch_metric_forward %b",str,i,j,branch_metric_forward[i][j]); 
                     $display("PMUGamma %s state %d radix_in %d branch_metric_backward %b",str,i,j,branch_metric_backward[i][j]); 
                   end
                 $display("PMUGamma %s forward state %d old_metric_sum %b new_metric_sum %b traceback %d need_rst %d",str,i,path_metric[i],tpl_1((tpl_1(pmuVectors))[i]),tpl_2((tpl_1(pmuVectors))[i]),need_rst);
                 $display("PMUGamma %s backward state %d old_metric_sum %b new_metric_sum %b traceback %d need_rst %d",str,i,path_metric[i],tpl_1((tpl_2(pmuVectors))[i]),tpl_2((tpl_2(pmuVectors))[i]),need_rst);
               end
           //end
      endmethod  
   endinterface
      
   interface Get out;
      method ActionValue#(VPathMetricUnitOut) get() if (can_read[0]); 
         //if(`DEBUG_CONV_DECODER == 1)
          // begin
             $display("PMUGamma %s outputs %s", str, fshow(zip(tpl_2(pmu_out_gamma),tpl_2(pmu_out))));
             $display("%s fires out at %t", str, $time);
             $display("%s dataOut: ", str, dataOut + 1);

          // Find the minimum value
          let vecA = tpl_2(pmu_out);
          let vecB = tpl_2(pmu_out_gamma);
          let errA = tpl_1(unzip(vecA));
          let errB = tpl_1(unzip(vecB));
   
          let forwardReverse = zip(errB,errA);
          let errAMinIndex =tpl_1(fold(chooseMin,zip(genWith(fromInteger),errA))); 
          let errBMinIndex =tpl_1(fold(chooseMin,zip(genWith(fromInteger),errB))); 
          let errAMin = errA[tpl_1(fold(chooseMin,zip(genWith(fromInteger),errA)))];
          let errBMin = errB[tpl_1(fold(chooseMin,zip(genWith(fromInteger),errB)))];
            $display("PMUGamma Out Min %d: %s PMUGamma OutGamma Min %d: %s ",errAMinIndex,fshow(errAMin),errBMinIndex,fshow(errBMin));
          // end

         can_read[0] <= False;
         dataOut <= dataOut + 1;         
         return pmu_out_gamma;
      endmethod
   endinterface
  
endmodule