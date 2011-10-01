import Vector::*;
import FShow::*;

// import ReversalBuffer::*;

// import LibraryFunctions::*;

// import ProtocolParameters::*;
// import VParams::*;

// Local includes
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"

// This file contains some parameters for configuring the BCJR encoder.

typedef TAdd#(TLog#(`REVERSAL_BUFFER_SIZE),1) ReversalGranularitySz;
typedef TMul#(2,`REVERSAL_BUFFER_SIZE) ForwardDelay;
Bit#(`REVERSAL_BUFFER_SIZE) reversalGranularity = `REVERSAL_BUFFER_SIZE;


// permutation required after acs
//This must also change, changing only the indexes is probably okay
function Vector#(VTotalStates,payload_t) permuteBackward(Vector#(VTotalStates,payload_t) in_vec);
   Integer comm_val = no_states / radix_sz;
   Vector#(VTotalStates,payload_t) out_vec = newVector;
   for (Integer i = 0; i < comm_val; i = i + 1)
      for (Integer j = 0; j < radix_sz; j = j + 1)
         out_vec[i*radix_sz+j] = in_vec[j*comm_val+i]; // new state = old state cyclic left shift
   return out_vec;
endfunction



(* noinline *)
function Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric))
   getBranchMetricBackward(Vector#(VNoBranchMetric,VBranchMetric) branch_metric);
   Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) out_vec = newVector;
   Bit#(VNoExtendedPoly) idx;
   for (Integer i = 0; i < no_states; i = i + 1)
      for (Integer j = 0; j < radix_sz; j = j + 1)
         begin
            idx = pack(map(genXORFeedback(fromInteger(2*i + j)),getExtendedPolys)); // the expected output bits of this transition
            out_vec[i][j] = branch_metric[idx]; // get the branch metric for this state
         end                    
   return out_vec;
endfunction


(* noinline *)
function Vector#(VRadixSz, VACSEntry) pathAdd(Vector#(VRadixSz, VPathMetric) path_metric, 
                                          Vector#(VRadixSz, Vector#(VRadixSz, VBranchMetric)) branch_metric);
   Vector#(VRadixSz, VACSEntry)   out_vec  = newVector;
   Vector#(VRadixSz, VPathMetric) tmp_vec  = newVector;
   Vector#(VRadixSz, VACSEntry)   tmp_vec2 = newVector;
   for (Integer i = 0; i < radix_sz; i = i + 1) // twice for the adjacent path metrics...
      begin
         for (Integer j = 0; j < radix_sz; j = j + 1)
            tmp_vec[j] =  path_metric[j] + signExtend(branch_metric[j][i]);  // update path metric
         out_vec[i] = tuple2(fold(\+ , tmp_vec),1); //sum path metrics
      end
   return out_vec;
endfunction

function Vector#(VTotalStates,VACSEntry) getPMUOutBCJRBackward
         (Vector#(VTotalStates, VPathMetric) path_metric,
          Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric);
   Vector#(VTotalStates,VACSEntry)                                      out_vec           = newVector;
   Vector#(VNoACS, Vector#(VRadixSz, VPathMetric))                      tmp_path_metric   = unpack(pack(permuteBackward(path_metric)));

   Vector#(VNoACS, Vector#(VRadixSz, Vector#(VRadixSz, VBranchMetric))) tmp_branch_metric = unpack(pack(permuteBackward(branch_metric)));
   out_vec = unpack(pack(zipWith(acs,tmp_path_metric,tmp_branch_metric)));
   return out_vec;   
endfunction


function Vector#(VTotalStates,VACSEntry) getPMUOutBCJRForward
         (Vector#(VTotalStates, VPathMetric) path_metric,
          Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric);
   Vector#(VTotalStates,VACSEntry)                                      out_vec           = newVector;
   Vector#(VNoACS, Vector#(VRadixSz, VPathMetric))                      tmp_path_metric   = unpack(pack(path_metric));

   Vector#(VNoACS, Vector#(VRadixSz, Vector#(VRadixSz, VBranchMetric))) tmp_branch_metric = unpack(pack(branch_metric));
   out_vec = unpack(pack(zipWith(acs,tmp_path_metric,tmp_branch_metric)));
   return permuteForward(out_vec);   
endfunction

function Tuple2#(Vector#(VTotalStates,VACSEntry),
                 Vector#(VTotalStates,VACSEntry)) getPMUOutBCJRForwardGamma
         (Vector#(VTotalStates, VPathMetric) path_metric,
          Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric_forward,
          Vector#(VTotalStates,Vector#(VRadixSz,VBranchMetric)) branch_metric_backward);
   Vector#(VTotalStates,VACSEntry)                                      path_vec           = newVector;
   Vector#(VTotalStates,VACSEntry)                                      gamma_vec           = newVector;
   Vector#(VNoACS, Vector#(VRadixSz, VPathMetric))                      tmp_path_metric   = unpack(pack(path_metric));

   Vector#(VNoACS, Vector#(VRadixSz, Vector#(VRadixSz, VBranchMetric))) tmp_branch_metric = unpack(pack(branch_metric_forward));
   path_vec = unpack(pack(zipWith(acs,tmp_path_metric,tmp_branch_metric)));

   Vector#(VTotalStates,VPathMetric) gammas = map(signExtend,map(fold( \+ ), branch_metric_backward));
   Vector#(VTotalStates, VPathMetric) gamma_temp = zipWith( \+ ,tpl_1(unzip(path_vec)),
                                                                gammas);

   return tuple2(permuteForward(path_vec),permuteForward(zip(gamma_temp,tpl_2(unzip(path_vec)))));   
endfunction

// Misc Defines

typedef Bit#(24) BCJRBitId;

// Reversal buffer control type
typedef struct {
  Bool last;
  BCJRBitId bitId;
} BCJRBackwardCtrl deriving (Bits,Eq);
      
instance FShow#(BCJRBackwardCtrl);
  function Fmt fshow(BCJRBackwardCtrl val);
    return $format("last: ") + fshow(val.last) + $format(" bitId: ") + fshow(val.bitId);
  endfunction
endinstance

typedef struct {
  BCJRBackwardCtrl backwardCtrl; 
  VBranchMetricUnitOut metric;
} BackwardPathCtrl deriving(Bits,Eq);

instance FShow#(BackwardPathCtrl);
  function Fmt fshow(BackwardPathCtrl val);
    return $format("backwardCtrl: ") + fshow(val.backwardCtrl) + $format(" metric: ") + fshow(val.metric);
  endfunction
endinstance

// Select where the PMU backward state comes from.
// must handle last state differently...
// At some point, we can probably optimize this by 
// stuffing in padding data at the beginning.....
// trading time for space.
typedef enum {
  Default,
  PMUEst
} PMUBackwardIntialState deriving(Bits,Eq);

instance FShow#(PMUBackwardIntialState);
  function Fmt fshow(PMUBackwardIntialState val);
    case (val)  
      Default : return $format(" DEFAULT ");
      PMUEst :  return $format(" PMUEST ");
    endcase
  endfunction
endinstance

instance ReversalBufferCtrl#(BCJRBackwardCtrl);
  function Bool isLast(BCJRBackwardCtrl x); 
    return x.last; 
  endfunction 
  function Bool isData(BCJRBackwardCtrl x); 
    return !x.last; 
  endfunction 
endinstance

typedef struct {
  Vector#(FwdSteps,Bit#(ConvInSz)) res;
  ExtendedPathMetric               soft_phy_hints;
} DecisionOutType deriving(Bits,Eq);
 
function ActionValue#(DecisionOutType) calculateDecision(Vector#(VTotalStates,ExtendedPathMetric) in_data);
  actionvalue
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
      
    if(`DEBUG_BCJR == 1) 
      begin
        $display("path_metric_sums: ", fshow(path_metric_sums));
        $display("other_path_metric_sums: ", fshow(other_path_metric_sums));
        $display("zero_sums: ", fshow(zero_sums));
        $display("one_sums: ", fshow(one_sums)); 
        $display("Decision Unit Max : %d (%h, check %h) Bit out: %h Other bit: %d (%h, check %h), hints (diff of two bits) %h", min_idx, min_path_metric, tpl_2(path_metric_sums[min_idx]), res, other_min_idx, other_min_path_metric, tpl_2(path_metric_sums[other_min_idx]),soft_phy_hints);
      end
    return DecisionOutType{res: res, soft_phy_hints: soft_phy_hints};
  endactionvalue
endfunction