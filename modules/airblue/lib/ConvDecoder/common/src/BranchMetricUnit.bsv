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

// import project libraries
// import ProtocolParameters::*;
// import ViterbiParameters::*;
// import VParams::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"

//`define isDebug True // uncomment this line to display error

/////////////////////////////////////////////////////////////////////////
// Definition of BranchMetricUnit Interface and useful types

interface BranchMetricUnit;
   method Put#(VInType)            in;
   method Get#(VBranchMetricUnitOut) out;
endinterface


// the bit width of the extended polynomials = (FwdSteps - 1) * ConvInSz + KSz
typedef Bit#(TAdd#(TMul#(TSub#(FwdSteps,1),ConvInSz),KSz)) ExtendedPolyType;

/////////////////////////////////////////////////////////////////////////
// Definitions of Auxiliary Functions

// convert metric to fixed point value with the range of [-1,1)
// whereas -1 means strongest 1 and 1 means strongest 0
// for MetricSz = 3, the conversion will be
// 000 -> 011, 001 -> 010, 010 -> 001, 011 -> 000,
// 100 -> 111, 101 -> 110, 110 -> 101, 111 -> 100
function VMetric convertMetric(VMetric in);
   return {in[metric_sz-1],~in[metric_sz-2:0]}; //MSB same, other bits flipped
endfunction

function VBranchMetric getAddMetric (Bool op_mode, VMetric met);
   VBranchMetric result;
   if(met == minBound)
     begin
       result = (op_mode ? maxBound : minBound);
     end
   else
     begin
       result = signExtend((op_mode ? -met : met));
     end
   return result;
endfunction


(* synthesize *)
module mkBranchMetricUnit (BranchMetricUnit);
   
   // states
   FIFO#(VInType)              in_q  <- mkLFIFO;
   FIFO#(VBranchMetricUnitOut) out_q <- mkLFIFO;
   
   rule getBranchMetric(True);
      VInType                                in_tup       = in_q.first;
      Bool                                   need_rst     = tpl_1(in_tup);
      Vector#(VNoExtendedPoly,VMetric)       observed_vec = unpack(pack(tpl_2(in_tup)));
//      observed_vec = map(convertMetric,observed_vec);
      Vector#(VNoExtendedPoly,Bool)          op_vec       = newVector;
      Vector#(VNoExtendedPoly,VBranchMetric) tmp_vec      = newVector;      
      Vector#(VNoBranchMetric,VBranchMetric) out_vec      = newVector;
      for (Integer i = 0; i < no_branch_metric; i = i + 1)
         begin
            op_vec     = unpack(fromInteger(i)); // This unpack seems like a bad idea...  
            tmp_vec    = zipWith(getAddMetric, op_vec, observed_vec); // Negate  distances in preparation for subtraction
            out_vec[i] = fold(\+ ,tmp_vec); // add them all up

            if(`DEBUG_CONV_DECODER == 1)
              begin
                $display("BMU code alphabet %b branch_metric %d",i,out_vec[i]); 
              end        
         end
      in_q.deq;
      out_q.enq(tuple2(need_rst,out_vec));
   endrule      
   
   interface in  = fifoToPut(in_q);
   interface out = fifoToGet(out_q); 
   
endmodule