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

/////////////////////////////////////////////////////////////////////////
// Definition of TracebackUnit Interface and usefule types

interface TracebackUnit;
   method Put#(VPathMetricUnitOut)  in;
   method Get#(Tuple2#(Bool,VState)) out;
   method Vector#(VRadixSz,VTBMemoryEntry) getTBPaths(VState state); // useful to SOVA 
endinterface

typedef TMul#(VNoTBStages, VTBSz)            VTBMemoryWidth;
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

function atype getTBPath(Vector#(VRadixSz,atype) tb_mems,
                         VTBType                 tb_bits);
   return tb_mems[tb_bits];
endfunction

function Tuple2#(Bit#(bsz),Bit#(csz)) shiftInMSBs (Bit#(bsz) old_data,
                                                   Bit#(asz) shift_in_data)
   provisos (Add#(asz,bsz,absz), Add#(bsz,asz,absz), Add#(xxA,csz,absz));
   Bit#(absz) concat_data = {shift_in_data, old_data}; 
   Bit#(bsz)  tup1        = tpl_1(split(concat_data));
   Bit#(csz)  tup2        = tpl_2(split(concat_data));
   return tuple2(tup1,tup2);
endfunction


/////////////////////////////////////////////////////////////////////////
// Implementation of TracebackUnit

(* synthesize *)
module mkTracebackUnit (TracebackUnit);

   // states
   Reg#(VTBStageIdx)                          tb_count   <- mkReg(fromInteger(no_tb_stages)); // output the first value after counting to 0 (skip first NoTBStages)
   Reg#(Vector#(VTotalStates,VTBMemoryEntry)) tb_memory  <- mkReg(replicate(0));
   FIFO#(Tuple2#(Bool,VState))                out_data_q <- mkSizedFIFO(2);
   Reg#(Bit#(15))                             bitsOut    <- mkReg(0);  

   Vector#(VRadixSz,Vector#(VTotalStates,VTBMemoryEntry)) expanded_memory  = replicate(tb_memory);
   Vector#(VTotalStates,Vector#(VRadixSz,VTBMemoryEntry)) repack_memory    = unpack(pack(expanded_memory));
   
   interface Put in;
      method Action put(VPathMetricUnitOut in_tup);
         Bool                                                   need_rst         = tpl_1(in_tup);
         Vector#(VTotalStates,VACSEntry)                        in_data          = tpl_2(in_tup);         
         if(`DEBUG_CONV_DECODER  == 1)
            $display("%m Viterbi Forward Vector: ", fshow(tpl_1(unzip(in_data)))); 

         Vector#(VTotalStates,VPathMetric)                      path_metric_vec  = newVector;       
         Vector#(VTotalStates,VTBType)                          tb_bits          = newVector;
   

         for(Integer i = 0; i < valueOf(VTotalStates); i = i + 1)
            begin
               path_metric_vec[i] = tpl_1(in_data[i]);
               tb_bits[i]         = tpl_2(in_data[i]);
            end
         Vector#(VTotalStates,Tuple2#(VState,VPathMetric))      path_metric_sums = zip(genWith(fromInteger), path_metric_vec);
         VState                                                 min_idx;
         if(`VITERBI_TB_MAX_PATH == 1) // traceback from the most likely path or 0? 
            min_idx          = tpl_1(fold(chooseMax, path_metric_sums));
      	 else
            min_idx          = 0;
         
         Vector#(VTotalStates,VTBMemoryEntry)                   tb_path_memory   = zipWith(getTBPath, repack_memory, tb_bits);                  
         Vector#(VTotalStates,VState)                           state_id         = genWith(fromInteger);
         Vector#(VTotalStates,VTBType)                          state_msbs       = map(getMSBs,state_id);
         Vector#(VTotalStates,Tuple2#(VTBMemoryEntry,VState))   shifted_memory   = zipWith(shiftInMSBs, tb_path_memory, state_msbs);
         VState                                                 res              = tpl_2(shifted_memory[min_idx]); 
         if(`DEBUG_CONV_DECODER == 1)
            $display("%m Viterbi TBSz: %d",tb_count);
         tb_memory <= tpl_1(unzip(shifted_memory));
         if (tb_count != 0)
            tb_count <= tb_count - 1;
         else
            begin
               if (need_rst)
                 begin
                  tb_count <= fromInteger(no_tb_stages);
                  bitsOut <= 0;
                 end
               else
                 begin
                   bitsOut <= bitsOut + 1;
                 end

               out_data_q.enq(tuple2(need_rst,res));

               if(`DEBUG_CONV_DECODER == 1)
                  begin
                     $display("%m Soft Traceback Unit Max : %d Bit out: %h, bit_count %d", min_idx, res, bitsOut+1);       
                     $display("%m TBU min_idx %d out_q.enq %d need_rst %d",min_idx,res, need_rst);
                  end
            end
      endmethod
   endinterface                
   
   interface Get out;
      method ActionValue#(Tuple2#(Bool,VState)) get();
         out_data_q.deq;
         // viterbi doesn't support soft phy hints, just output junk
         return out_data_q.first;
      endmethod
   endinterface
   
   method Vector#(VRadixSz,VTBMemoryEntry) getTBPaths(VState state);
      return repack_memory[state];
   endmethod

endmodule


