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

//`define isDebug True // uncomment this line to display error

//`define softOut True // comment this line if soft output viterbi is not needed 

/////////////////////////////////////////////////////////////////////////
// Definition of TracebackUnit Interface and usefule types

interface TracebackUnit;
   method Put#(VPathMetricUnitOut)  in;
   method Get#(VOutType) out;
endinterface

typedef TMul#(VNoTBStages, VTBSz)            VTBMemoryWidth;
typedef TSub#(VTBMemoryWidth,VStateSz)       VSoftWidth; 
typedef Bit#(VTBMemoryWidth)                 VTBMemoryEntry;

/////////////////////////////////////////////////////////////////////////
// Definitions of Auxiliary Functions

// choose the larger of the two
function Tuple2#(VState, VPathMetric) chooseMax (Tuple2#(VState, VPathMetric) in1, 
                                                 Tuple2#(VState, VPathMetric) in2);
   return ((tpl_2(in1) - tpl_2(in2)) < path_metric_threshold) ? in1 : in2; 
endfunction // Tuple3

function Bit#(asz) getMSBs (Bit#(bsz) in_data)
   provisos (Add#(asz,xxA,bsz));
   return tpl_1(split(in_data));
endfunction

// function VTBMemoryEntry getTBPath(Vector#(VRadixSz,VTBMemoryEntry) tb_mems,
//                                   VTBType                          tb_bits);
//    return tb_mems[tb_bits];
// endfunction

function atype getTBPath(Vector#(VRadixSz,atype) tb_mems,
                         VTBType                 tb_bits);
   return tb_mems[tb_bits];
endfunction

function Tuple2#(Bit#(bsz),Bit#(asz)) shiftInMSBs (Bit#(bsz) old_data,
                                                   Bit#(asz) shift_in_data)
   provisos (Add#(asz,bsz,absz), Add#(bsz,asz,absz));
   return split({shift_in_data, old_data});
endfunction


function  Vector#(VSoftWidth,VPathMetric) getSoftOuts (Vector#(VSoftWidth,VPathMetric)        soft_outs,
                                                       Tuple2#(VTBMemoryEntry,VTBMemoryEntry) tb_paths,
                                                       VPathMetric                            delta);
   VTBMemoryEntry                        best_path        = tpl_1(tb_paths);
   VTBMemoryEntry                        second_best_path = tpl_2(tb_paths);
   VTBMemoryEntry                        diff_path        = best_path ^ second_best_path; // positions where best_path and second_best_path will be 1, otherwise 0
   Vector#(VSoftWidth,VPathMetric)       new_soft_outs     = soft_outs;                     
   for (Integer i = 0; i < valueOf(VSoftWidth); i = i + 1)
      if (i != valueOf(VSoftWidth)-1)
         new_soft_outs[i] = (diff_path[i] == 1 && (delta < new_soft_outs[i+1])) ? delta : new_soft_outs[i+1];
      else
         new_soft_outs[i] = (diff_path[i] == 1) ? delta : maxBound;
   return new_soft_outs;
endfunction


/////////////////////////////////////////////////////////////////////////
// Implementation of TracebackUnit

(* synthesize *)
module mkTracebackUnit (TracebackUnit);

   // states
   Reg#(VTBStageIdx)                          tb_count   <- mkReg(fromInteger(no_tb_stages)); // output the first value after counting to 0 (skip first NoTBStages)
   Reg#(Vector#(VTotalStates,VTBMemoryEntry)) tb_memory  <- mkReg(replicate(0));
   FIFO#(Vector#(FwdSteps,Bit#(ConvInSz)))    out_data_q <- mkSizedFIFO(2);
   
   `ifdef softOut 
   Reg#(Vector#(VTotalStates,Vector#(VSoftWidth,VPathMetric)))  soft_outs_reg  <- mkReg(replicate(maxBound)); // for each traceback column, there is a soft output
   `endif
   
   interface Put in;
      method Action put(VPathMetricUnitOut in_tup);
         Bool                                                   need_rst         = tpl_1(in_tup);
         Vector#(VTotalStates,VACSEntry)                        in_data          = tpl_2(in_tup);         
         $display("Viterbi Forward Vector: ", fshow(tpl_1(unzip(in_data)))); 

         Vector#(VTotalStates,VPathMetric)                      path_metric_vec  = newVector;       
         Vector#(VTotalStates,VTBType)                          tb_bits          = newVector;

         `ifdef softOut
         Vector#(VTotalStates,VTBType)                          sb_tb_bits       = newVector; // second best traceback bits
         Vector#(VTotalStates,VPathMetric)                      delta_vec        = newVector;
         `endif

         for(Integer i = 0; i < valueOf(VTotalStates); i = i + 1)
            begin
               path_metric_vec[i] = tpl_1(in_data[i]);
               tb_bits[i]         = tpl_2(in_data[i]);

               `ifdef softOut
               sb_tb_bits[i]      = tpl_3(in_data[i]);
               delta_vec[i]       = tpl_4(in_data[i]);
               `endif

            end
         Vector#(VTotalStates,Tuple2#(VState,VPathMetric))      path_metric_sums = zip(genWith(fromInteger), path_metric_vec);
         VState                                                 min_idx          = tpl_1(fold(chooseMax, path_metric_sums));
      	 

         Vector#(VRadixSz,Vector#(VTotalStates,VTBMemoryEntry)) expanded_memory  = replicate(tb_memory);
         Vector#(VTotalStates,Vector#(VRadixSz,VTBMemoryEntry)) repack_memory    = unpack(pack(expanded_memory));
         Vector#(VTotalStates,VTBMemoryEntry)                   tb_path_memory   = zipWith(getTBPath, repack_memory, tb_bits);                  
         Vector#(VTotalStates,VState)                           state_id         = genWith(fromInteger);
         Vector#(VTotalStates,Tuple2#(VTBMemoryEntry,VTBType))  shifted_memory   = zipWith(shiftInMSBs, tb_path_memory, map(getMSBs,state_id));
         Vector#(FwdSteps,Bit#(ConvInSz))                       res              = unpack(pack(tpl_2(shifted_memory[min_idx]))); 
         `ifdef softOut
         Vector#(VRadixSz,Vector#(VTotalStates,Vector#(VSoftWidth,VPathMetric))) expanded_soft_outs = replicate(soft_outs_reg);
         Vector#(VTotalStates,Vector#(VRadixSz,Vector#(VSoftWidth,VPathMetric))) repack_soft_outs   = unpack(pack(expanded_soft_outs));
         Vector#(VTotalStates,Vector#(VSoftWidth,VPathMetric))                   temp_soft_outs     = zipWith(getTBPath, repack_soft_outs, tb_bits);
         Vector#(VTotalStates,VTBMemoryEntry)                   sb_tb_path_memory = zipWith(getTBPath, repack_memory, sb_tb_bits);
         Vector#(VTotalStates,Vector#(VSoftWidth,VPathMetric))  soft_outs         = zipWith3(getSoftOuts,temp_soft_outs, zip(tb_path_memory,sb_tb_path_memory), delta_vec);
         VPathMetric                                            soft_out          = soft_outs_reg[min_idx][0]; 
         soft_outs_reg <= soft_outs;

         `endif
         $display("Viterbi TBSz: %d",tb_count);
         tb_memory <= tpl_1(unzip(shifted_memory));
         if (tb_count != 0)
            tb_count <= tb_count - 1;
         else
            begin
               if (need_rst)
                  tb_count <= fromInteger(no_tb_stages);
               $display("Traceback Unit Max : %d Bit out: %h", min_idx, res);       
               out_data_q.enq(res);
               `ifdef isDebug
               $display("TBU min_idx %d out_q.enq %d need_rst %d",min_idx,res, need_rst);
               `endif
               `ifdef softOut
               $display("TBU soft decision %d",soft_out);
               `endif
            end
      endmethod
   endinterface                
   
   interface Get out;
      method ActionValue#(VOutType) get();
         out_data_q.deq;
         // viterbi doesn't support soft phy hints, just output junk
         return tuple2(out_data_q.first,?);
      endmethod
   endinterface
endmodule


