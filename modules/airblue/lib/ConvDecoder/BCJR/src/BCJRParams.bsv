import Vector::*;
import FShow::*;

// import ReversalBuffer::*;

// import LibraryFunctions::*;

// import ProtocolParameters::*;
// import VParams::*;

// Local includes
`include "asim/provides/reversal_buffer.bsh"
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