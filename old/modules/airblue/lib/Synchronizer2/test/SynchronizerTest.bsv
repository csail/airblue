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

import CBus::*;
import Complex::*;
import FIFOF::*;
import FixedPoint::*;
import FShow::*;
import GetPut::*;
import Vector::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_synchronizer_packetgen.bsh"
`include "asim/provides/airblue_special_fifos.bsh"

`include "asim/rrr/client_stub_SYNCHRONIZERDRIVER.bsh"
`include "asim/rrr/server_stub_SYNCHRONIZERDRIVER.bsh"

// to deal with the case where synchronizer may output some initialization junk samples, will try to adjust the expected position accordingly 
`define SyncPosAdjustment 0


(* synthesize *)
module mkStatefulSynchronizerInstance(StatefulSynchronizer);
   let ifc <- exposeCBusIFC(mkStatefulSynchronizer); 
   let statefulSynchronizer = ifc.device_ifc;
   return statefulSynchronizer;
endmodule


module [CONNECTED_MODULE] mkHWOnlyApplication ();   
   let test <- mkSynchronizerTest;
endmodule

   
module [CONNECTED_MODULE] mkSynchronizerTest ();
   let clientStub <- mkClientStub_SYNCHRONIZERDRIVER();
   let serverStub <- mkServerStub_SYNCHRONIZERDRIVER();

   // states
   StatefulSynchronizer statefulSynchronizer <- mkStatefulSynchronizerInstance();
   Synchronizer#(2,14) synchronizer = statefulSynchronizer.synchronizer;

   StreamFIFO#(80, 7, FPComplex#(1, 9)) inQ <- mkStreamFIFO;
   StreamFIFO#(80, 7, Bool) outQ <- mkStreamFIFO;

   function Vector#(3,FPComplex#(1,9)) unpackSamples(Bit#(64) data);
      return unpack(truncate(data));
   endfunction

   rule fromChannel (inQ.notFull(6));
      let out <- serverStub.acceptRequest_SynchronizerIn6();
      let samples1 = unpackSamples(out.data1);
      let samples2 = unpackSamples(out.data2);

      inQ.enq(6, append(append(samples1, samples2), ?));
   endrule

   rule toSynchronizer (inQ.notEmpty(1));
      let data = inQ.first[0];
      synchronizer.in.put(fpcmplxSignExtend(data));
      inQ.deq(1);
   endrule

   rule fromSynchronizer (outQ.notFull(1));
      let result <- synchronizer.out.get;
      let resultCmplx = result.data;
      outQ.enq(1, cons(result.control.isNewPacket, ?));
   endrule

   rule toChannel (outQ.notEmpty(6));
      Vector#(6, Bool) syncs = take(outQ.first);
      clientStub.makeRequest_SynchronizerOut6(extend(pack(syncs)));
      outQ.deq(6);
   endrule

endmodule
