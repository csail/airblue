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

/////////////////////////////////////////////////////////////////////////
// Definition of TracebackUnit Interface and usefule types

interface SoftPathDetector;
   method Put#(Tuple2#(VState,VPathMetricUnitOut)) in;
   method Get#(VSoftOut)                           out;
endinterface

typedef TSub#(VTBMemoryWidth,VStateSz) VSoftWidth; 

/////////////////////////////////////////////////////////////////////////
// Definitions of Auxiliary Functions

function  Vector#(VNoTBStages,VPathMetric) getSoftOuts (Vector#(VNoTBStages,VPathMetric)        soft_outs,
                                                       Tuple2#(VTBMemoryEntry,VTBMemoryEntry) tb_paths,
                                                       VPathMetric                            delta);
   VTBMemoryEntry                        best_path        = tpl_1(tb_paths);
   VTBMemoryEntry                        second_best_path = tpl_2(tb_paths);
   VTBMemoryEntry                        diff_path        = best_path ^ second_best_path; // positions where best_path and second_best_path will be 1, otherwise 0
   Vector#(VNoTBStages,VPathMetric)       new_soft_outs    = soft_outs;                     
   for (Integer i = 0; i < valueOf(VNoTBStages); i = i + 1)
      if (i != valueOf(VNoTBStages)-1)
         new_soft_outs[i] = (diff_path[i] == 1 && (delta < new_soft_outs[i+1])) ? delta : new_soft_outs[i+1];
      else
         new_soft_outs[i] = (diff_path[i] == 1) ? delta : maxBound;
   return new_soft_outs;
endfunction


/////////////////////////////////////////////////////////////////////////
// Implementation of TracebackUnit

(* synthesize *)
module mkSoftPathDetector (SoftPathDetector);
   
   // constants
   Vector#(VNoTBStages,VPathMetric)         init_soft_outs = replicate(maxBound);
   
   // states
   Reg#(VTBStageIdx)                       tb_count       <- mkReg(fromInteger(no_tb_stages)); // output the first value after counting to 0 (skip first NoTBStages)
   TracebackUnit                           tb             <- mkTracebackUnit();
   Reg#(Vector#(VNoTBStages,VPathMetric))   soft_outs_reg  <- mkReg(init_soft_outs); // for each traceback column, there is a soft output
   FIFO#(VPathMetric)                      soft_hints_q   <- mkSizedFIFO(2);
   
   interface Put in;
      method Action put(Tuple2#(VState,VPathMetricUnitOut) in_tup);
         VState                                 state             = tpl_1(in_tup);
         VPathMetricUnitOut                     tb_in_tup         = tpl_2(in_tup);
         Bool                                   need_rst          = tpl_1(tb_in_tup);
         VPathMetric                            path_metric_delta = tpl_4((tpl_2(tb_in_tup))[state]);
         VTBType                                best_tb_idx       = tpl_2((tpl_2(tb_in_tup))[state]); 
         Vector#(VRadixSz,VTBMemoryEntry)       tb_paths          = tb.getTBPaths(state);
         Tuple2#(VTBMemoryEntry,VTBMemoryEntry) soft_tb_paths     = (best_tb_idx != 0) ? tuple2(tb_paths[1],tb_paths[0]): tuple2(tb_paths[0],tb_paths[1]); 
         Vector#(VNoTBStages,VPathMetric)        soft_outs         = getSoftOuts(soft_outs_reg, soft_tb_paths, path_metric_delta);         
         VPathMetric                            soft_out          = soft_outs_reg[0]; 
         tb.in.put(tb_in_tup);
         soft_outs_reg <= soft_outs;
         if(`DEBUG_CONV_DECODER == 1)
            begin
               $display("SoftPathDetector TBSz: %d",tb_count);
               $write("SoftPathDetector new_soft_outs_reg: ");
               for (Integer i = 0; i < valueOf(VNoTBStages); i = i + 1)
                  $write("%d ",soft_outs[i]);
               $display("");
               $write("SoftPathDetector incoming vstate: %d picked_path_delta: %d path_delta: ",state,path_metric_delta);
               for (Integer j = 0; j < no_states; j = j + 1)
                  $write("%d ",tpl_4((tpl_2(tb_in_tup))[j]));
               $display("");
            end
         if (tb_count != 0)
            tb_count <= tb_count - 1;
         else
            begin
               if (need_rst)
                  tb_count <= fromInteger(no_tb_stages);
               soft_hints_q.enq(soft_outs[0]);
            end
      endmethod
   endinterface                
   
   interface Get out;
      method ActionValue#(VSoftOut) get();
         let res <- tb.out.get();
         soft_hints_q.deq();
         return VSoftOut{data: unpack(truncate(pack(res))), path_metric: soft_hints_q.first()};
      endmethod
   endinterface
endmodule


