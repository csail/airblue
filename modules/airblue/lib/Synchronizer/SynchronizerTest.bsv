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

import DataTypes::*;
import Interfaces::*;
import Synchronizer::*;
import FixedPoint::*;
import Complex::*;
//import Preambles::*;
import SynchronizerLibrary::*;
import Vector::*;
import RegFile::*;
import FPComplex::*;
import GetPut::*;
import Controls::*;
import CBus::*;

(* synthesize *)
module [Module] mkStatefulSynchronizerInstance(StatefulSynchronizer#(2,14));
   let ifc <- exposeCBusIFC(mkStatefulSynchronizer); 
   let statefulSynchronizer = ifc.device_ifc;
   return statefulSynchronizer;
endmodule

(* synthesize *)
module mkSynchronizerTest(Empty);

   // states
   StatefulSynchronizer#(2,14) statefulSynchronizer <- mkStatefulSynchronizerInstance();
   Synchronizer#(2,14) synchronizer = statefulSynchronizer.synchronizer;
   
   Reg#(Bit#(14)) inCounter <- mkReg(0);
   Reg#(Bit#(14)) outCounter <- mkReg(0);
   
   // constant
   RegFile#(Bit#(14),FPComplex#(2,14)) packet <- mkRegFileFullLoad("WiFiPacket.txt");
   RegFile#(Bit#(14), FPComplex#(2,14)) tweakedPacket <- mkRegFileFullLoad("WiFiTweakedPacket.txt");
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule toSynchronizer(True);
      FPComplex#(2,14) inCmplx = tweakedPacket.sub(inCounter);
      inCounter <= inCounter + 1;
      synchronizer.in.put(inCmplx);
      $write("Execute toSync cycle: %d, at %d:",cycle,inCounter);
      cmplxWrite("("," + "," i)",fxptWrite(7),inCmplx);
      $display("");
   endrule

   rule fromSynchronizerToUnserializer(True);
      let result <- synchronizer.out.get;
      let resultCmplx = result.data;
      outCounter <= outCounter + 1;
      $write("Execute fromSyncToUnserializer at %d:", outCounter);
      $write("new message: %d, ", result.control.isNewPacket);
      cmplxWrite("("," + ","i)",fxptWrite(7),resultCmplx);
      $display("");
      $write("Cycle: %d; Expected Output at %d:", cycle, outCounter);
      cmplxWrite("("," + ","i)",fxptWrite(7),packet.sub(outCounter));
      $display("");
   endrule
   
   rule readCoarPow(True);
      $write("Cycle: %d; readCoarPow: ", cycle);
      fxptWrite(7,statefulSynchronizer.coarPow);
      $display("");
   endrule
   
   // tick
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 10000)
	 $finish();
      $display("cycle: %d",cycle);
   endrule
     
endmodule   



