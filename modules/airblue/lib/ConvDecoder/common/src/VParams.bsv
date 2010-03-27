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

import Vector::*;

// import DataTypes::*;
// import LibraryFunctions::*;
// import ProtocolParameters::*;
// import ViterbiParameters::*;

//`include "../../../WiFiFPGA/Macros.bsv"

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"

//`define softOut True // comment this line if soft output viterbi is not needed 

//  ////////////////////////////////////////
//  // Viterbi parameters
//  ////////////////////////////////////////

//  typedef 7  KSz;       // no of input bits 

//  //typedef 35 ViterbiTracebackLength;
//  typedef 35 TBLength;  // the minimum TB length for each output
//  typedef 5  NoOfDecodes;    // no of traceback per stage, TBLength dividible by this value

//  typedef 3  MetricSz;  // input metric = confident bits

//  typedef 1  FwdSteps;  // forward step per cycle, each butterfly can handle 2^FwdSteps inputs

//  typedef 4  FwdRadii;  // no. butterflies = 2^FwdRadii & 2^(FwdRadii+FwdSteps*ConvInSz) <= 2^(KSz-1)

//  typedef 1  ConvInSz;  // conv input size

//  typedef 2  ConvOutSz; // conv output size

//  Bit#(KSz) convEncoderG1 = 'b1111001;
//  Bit#(KSz) convEncoderG2 = 'b1011011;

////////////////////////////////////////
// Begin of type definitions
////////////////////////////////////////

typedef SizeOf#(ViterbiMetric)       MetricSz;
typedef TSub#(KSz,ConvInSz)          VStateSz;
typedef Bit#(VStateSz)               VState;
typedef TExp#(VStateSz)              VTotalStates;
typedef TExp#(KSz)                   VNoTransitions;
typedef Bit#(MetricSz)               VMetric;
typedef TSub#(TExp#(MetricSz),1)     VMetricMax;

// branch metric unit
typedef TMul#(FwdSteps,ConvOutSz)                             VNoExtendedPoly;
typedef TExp#(VNoExtendedPoly)                                VNoBranchMetric; // no. branch metric generarated by BMU
typedef TAdd#(TLog#(VNoExtendedPoly),MetricSz)                VBranchMetricSz;
typedef TMul#(VNoExtendedPoly,VMetricMax)                     VBranchMetricMax;
typedef Bit#(VBranchMetricSz)                                 VBranchMetric; // extended to be able to acuumulate VNoExtendedPoly of VMetric

// path metric unit
typedef TMul#(FwdSteps,ConvInSz)                              VTBSz; // 1
typedef TAdd#(TSub#(KSz,1),VBranchMetricSz)                   VPathMetricSz;
//typedef 9 VPathMetricSz; // add one more bit using murali method         
//typedef TAdd#(TAdd#(TLog#(TDiv#(KSz,VTBSz)),VBranchMetricSz),1) VPathMetricSz; // add one more bit using murali method
//typedef TMul#(TDiv#(KSz,VTBSz),VBranchMetricMax)              VPathMetricMax; 
// // max diff between two states = VBranchMetricMax * ceiling(KSz/ConvInSz)
typedef Bit#(VPathMetricSz)                                     VPathMetric;        //add one more bit using murali method 


typedef Tuple2#(Bool, 
                Vector#(FwdSteps, 
                        Vector#(ConvOutSz, VMetric)))        VInType;
`ifdef SOFT_PHY_HINTS
typedef Tuple2#(Vector#(FwdSteps, Bit#(ConvInSz)), VPathMetric) VOutType;
`else
typedef Vector#(FwdSteps, Bit#(ConvInSz))                    VOutType;
`endif

// no. extended conolutional generator polynomials = FwdSteps x ConvOutSz
typedef Tuple2#(Bool,
                Vector#(VNoBranchMetric, VBranchMetric))     VBranchMetricUnitOut; 

typedef struct {
  VBranchMetricUnitOut branchMetric;
  Vector#(VTotalStates,VPathMetric)  initPathMetric;
} PathMetricUnitIn deriving(Bits,Eq);

// for the butterfly
typedef TExp#(VTBSz)                                          VRadixSz;
typedef Bit#(VTBSz)                                           VTBType;
typedef TDiv#(VTotalStates, VRadixSz)                         VNoACS;

`ifdef softOut
typedef Tuple4#(VPathMetric, VTBType, VTBType, VPathMetric)   VACSEntry; // the first is accumulated path metric
                                                                         // the second is the best traceback idx
                                                                         // the third is the second best traceback idx
                                                                         // the fourth is the difference between the best and 2nd best path metric
`else
typedef Tuple2#(VPathMetric, VTBType)                         VACSEntry; // the first is accumulated path metric
                                                                         // the second is the traceback idx
`endif

// typedef Tuple2#(Bool,
//                 Vector#(VTotalStates, 
//                         Vector#(VRadixSz,VBranchMetric)))     VBranchMetricUnitOut;
// needs_rst, VACSEntry
typedef Tuple2#(Bool,
                Vector#(VTotalStates, VACSEntry))             VPathMetricUnitOut;
typedef TDiv#(TBLength, VTBSz)                                VNoTBStages; // no of tbstages
typedef Bit#(TLog#(TAdd#(VNoTBStages,1)))                     VTBStageIdx;  

typedef enum{
   NORMAL, // normal operation mode
   ZEROS   // pushing zeros to drive out data from viterbi
} ViterbiOpState deriving(Eq,Bits);


// Functions for path metric unit.  Perhaps that file should contain these?

// the bit width of the extended polynomials = (FwdSteps - 1) * ConvInSz + KSz
typedef Bit#(TAdd#(TMul#(TSub#(FwdSteps,1),ConvInSz),KSz)) VExtendedPolyType;

// extended the convolutional generator polynomials
function Vector#(VNoExtendedPoly,VExtendedPolyType) getExtendedPolys;
   Vector#(VNoExtendedPoly,VExtendedPolyType) out_polys = newVector;
   Vector#(ConvOutSz,VExtendedPolyType)       tmp_polys = map(zeroExtend, genConvPolys); // from ProtocolParmeters  
   for (Integer i = 0; i < fwd_steps; i = i + 1)
      for (Integer j = 0; j < conv_out_sz; j = j + 1)
         begin
            out_polys[i*conv_out_sz+j] = tmp_polys[j]; 
            tmp_polys[j] = tmp_polys[j] << conv_in_sz; // left shift by conv_in_sz
         end   
   return out_polys;
endfunction 


// permutation required after acs
//This must also change, changing only the indexes is probably okay
(* noinline *)
function Vector#(VTotalStates,VACSEntry) permuteForward(Vector#(VTotalStates,VACSEntry) in_vec);
   Integer comm_val = no_states / radix_sz;
   Vector#(VTotalStates,VACSEntry) out_vec = newVector;
   for (Integer i = 0; i < comm_val; i = i + 1)
      for (Integer j = 0; j < radix_sz; j = j + 1)
         out_vec[j*comm_val+i] = in_vec[i*radix_sz+j]; // new state = old state cyclic right shift
   return out_vec;
endfunction


// use the branch metric to get the right branch metric that should be added to acs with
// path metric
(* noinline *)
function Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric))
   getBranchMetricForward(Vector#(VNoBranchMetric,VBranchMetric) branch_metric);
   Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) out_vec = newVector;
   Bit#(VNoExtendedPoly) idx;
   for (Integer i = 0; i < no_states; i = i + 1)
      for (Integer j = 0; j < radix_sz; j = j + 1)
         begin
            idx = pack(map(genXORFeedback(fromInteger(j*no_states+i)),getExtendedPolys)); // the expected output bits of this transition
            out_vec[i][j] = branch_metric[idx]; // get the branch metric for this state
         end                    
   return out_vec;
endfunction



// choose the larger of the two
function VACSEntry chooseMax (VACSEntry in1, 
                              VACSEntry in2);
   VPathMetric delta = tpl_1(in1) - tpl_1(in2);
 
  `ifdef softOut

   VTBType     old_sb_tb1     = tpl_3(in1);
   VPathMetric old_delta1     = tpl_4(in1);
   VTBType     old_sb_tb2     = tpl_3(in2);
   VPathMetric old_delta2     = tpl_4(in2);
   VPathMetric neg_delta      = negate(delta);
   Bool        is_new_delta_1 = delta < old_delta1;      // second best is in1 
   Bool        is_new_delta_2 = neg_delta < old_delta2;  // second best is in2
   VACSEntry   out1           = is_new_delta_1 ? tuple4(tpl_1(in1),tpl_2(in1),tpl_2(in2),delta) : in1;
   VACSEntry   out2           = is_new_delta_2 ? tuple4(tpl_1(in2),tpl_2(in2),tpl_2(in1),neg_delta) : in2;

   `else   

   VACSEntry   out1           = in1;
   VACSEntry   out2           = in2;

   `endif

   return (delta < path_metric_threshold) ? out1 : out2;
endfunction // Tuple3

(* noinline *)
function Vector#(VRadixSz, VACSEntry) acs(Vector#(VRadixSz, VPathMetric) path_metric, 
                                          Vector#(VRadixSz, Vector#(VRadixSz, VBranchMetric)) branch_metric);
   Vector#(VRadixSz, VACSEntry)   out_vec  = newVector;
   Vector#(VRadixSz, VPathMetric) tmp_vec  = newVector;
   Vector#(VRadixSz, VACSEntry)   tmp_vec2 = newVector;
   for (Integer i = 0; i < radix_sz; i = i + 1)
      begin
         for (Integer j = 0; j < radix_sz; j = j + 1)
            tmp_vec[j] =  path_metric[j] + signExtend(branch_metric[j][i]);  // update path metric

         `ifdef softOut   
         tmp_vec2 = zip4(tmp_vec,genWith(fromInteger),?,replicate(maxBound)); // add traceback idx
         `else
         tmp_vec2 = zip(tmp_vec,genWith(fromInteger)); // add traceback idx
         `endif   

         out_vec[i] = fold(chooseMax, tmp_vec2); // select the one with best path metric
      end
   return out_vec;
endfunction

(* noinline *)
function Vector#(VTotalStates,VACSEntry) getPMUOutViterbi
         (Vector#(VTotalStates, VPathMetric) path_metric,
          Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric);
   Vector#(VTotalStates,VACSEntry)                                      out_vec           = newVector;
   Vector#(VNoACS, Vector#(VRadixSz, VPathMetric))                      tmp_path_metric   = unpack(pack(path_metric));
   Vector#(VNoACS, Vector#(VRadixSz, Vector#(VRadixSz, VBranchMetric))) tmp_branch_metric = unpack(pack(branch_metric));
   out_vec = unpack(pack(zipWith(acs,tmp_path_metric,tmp_branch_metric)));
   return permuteForward(out_vec);   
endfunction


/////////////////////////////////////////////////////////////////////////
// constants

Integer state_sz            = valueOf(VStateSz);
Integer no_transitions      = valueOf(VNoTransitions);
Integer fwd_steps           = valueOf(FwdSteps);
Integer radix_sz            = valueOf(VRadixSz);
Integer no_states           = valueOf(VTotalStates);
Integer conv_in_sz          = valueOf(ConvInSz);
Integer conv_out_sz         = valueOf(ConvOutSz);
Integer branch_metric_max   = valueOf(VBranchMetricMax);
Integer no_tb_stages        = valueOf(VNoTBStages);
Integer metric_sz           = valueOf(MetricSz);
Integer no_branch_metric    = valueOf(VNoBranchMetric);
VPathMetric path_metric_threshold = 1 << fromInteger(valueOf(VPathMetricSz)-1); // half of the max bound of VPathMetric
