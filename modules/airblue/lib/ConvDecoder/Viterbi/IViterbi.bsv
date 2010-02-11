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
import Connectable::*;
import GetPut::*;

// import project libraries
// viterbi not compatible with soft phy hints
import BranchMetricUnit::*;
import PathMetricUnit::*;
import TracebackUnit::*;
import ViterbiParameters::*;
import ProtocolParameters::*;
import VParams::*;

//`define isDebug True // uncomment this line to display error

//////////////////////////////////////////////////////////
// begin of IViterbi interface definitions

interface IViterbi;
  method Action putData (VInType dataIn);
  method ActionValue#(VOutType) getResult ();
endinterface
      
/////////////////////////////////////////////////////////
// Begin of Viterbi Module 

// viterbi not compatible with soft phy hints
(*synthesize*)
module mkIViterbiTBPath (IViterbi);
   
   BranchMetricUnit bmu <- mkBranchMetricUnit;
   PathMetricUnit   pmu <- mkPathMetricUnit("PMU Viterbi",getPMUOutViterbi,getBranchMetricForward);
   TracebackUnit    tbu <- mkTracebackUnit;
   
   //mkConnection(bmu.out, pmu.in);
   rule branchMetricTransfer;
     let branchMetric <- bmu.out.get;
     pmu.in.put(PathMetricUnitIn{branchMetric: branchMetric, initPathMetric:  initPathMetricZero()});
   endrule

   rule connectPMUTBU;
     let pmuOut <- pmu.out.get;
     tbu.in.put(pmuOut);
   endrule
   
   method Action putData (VInType in_data);
      bmu.in.put(in_data);
   endmethod

   method ActionValue#(VOutType) getResult();
      let res <- tbu.out.get();
      return res;
   endmethod
   
endmodule
