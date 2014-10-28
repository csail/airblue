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
import LFSR::*;
import RegFile::*;
import Vector::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/airblue_synchronizer_packetgen.bsh"

// to deal with the case where synchronizer may output some initialization junk samples, will try to adjust the expected position accordingly 
`define SyncPosAdjustment 11 


(* synthesize *)
module [Module] mkStatefulSynchronizerInstance(StatefulSynchronizer#(2,14));
   let ifc <- exposeCBusIFC(mkStatefulSynchronizer); 
   let statefulSynchronizer = ifc.device_ifc;
   return statefulSynchronizer;
endmodule

   
module mkHWOnlyApplication (Empty);   
   let test <- mkSynchronizerDiffTest();
endmodule
   
(* synthesize *)
module mkSynchronizerDiffTest(Empty);
   // states
   StatefulSynchronizer#(2,14) statefulSynchronizer <- mkStatefulSynchronizerInstance();
   Synchronizer#(2,14) synchronizer = statefulSynchronizer.synchronizer;
   
   PacketGenerator generator <- mkPacketGenerator(); // packet generator
   Channel#(2,14)  channel   <- mkChannel();  // channel that connect the packet generator to synchronizer with added noise
   
   Reg#(Bit#(16)) inCounter  <- mkReg(0);
   Reg#(Bit#(32)) outCounter <- mkReg(0);
   
   Reg#(Bit#(32))  expected_sync_pos <- mkReg(320+`SyncPosAdjustment); // the next expected synchronization position, the first one should start at 256th (assuming 0 is the 1st output)
   FIFOF#(Bit#(32)) expected_sync_pos_fifo <- mkSizedFIFOF(4); // check whether the expected synchronization position match
   Reg#(Bit#(16))   misses <- mkReg(0); // no. unsuccessfully detected packets
   Reg#(Bit#(16))   detected <- mkReg(0); // no. successfully detected packets
   Reg#(Bit#(16))   false  <- mkReg(0); // no. false positives
   
   // constant
   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFOF#(Bit#(32)) deq_fifo <- mkSizedFIFOF(4);

   FIFOF#(Bool) isDataFifo <- mkSizedFIFOF(8);
   FIFOF#(FPComplex#(2,14)) inData <- mkSizedFIFOF(1000);
   FIFOF#(FPComplex#(2,14)) outData <- mkSizedFIFOF(1000);

   let expected_pos = expected_sync_pos_fifo.first();
   
   rule printState;
      $display("Cycle %d: expected_sync_pos_fifo ",cycle, fshow(expected_sync_pos_fifo));
   endrule
   
   rule startNextPacket(inCounter == 0);
      let len <- generator.nextLength.get();
      let new_expected_sync_pos = expected_sync_pos + zeroExtend(len);
      inCounter <= len; 
      expected_sync_pos <= new_expected_sync_pos;
      expected_sync_pos_fifo.enq(expected_sync_pos);
      $display("Cycle %d: %m startNextPacket packet_length = %d, expected_synchronization_postion = %d", cycle, len, expected_sync_pos);
   endrule
   
   rule toChannel(inCounter > 0);
      FPComplex#(2,14) inCmplx <- generator.nextData.get();
      isDataFifo.enq(generator.isData);
      inCounter <= inCounter - 1;
      channel.in.put(inCmplx);
   endrule

   rule toSynchronizer(True);
      FPComplex#(2,14) inCmplx <- channel.out.get(); 
      if (isDataFifo.first)
         begin
            inData.enq(inCmplx);
         end
      isDataFifo.deq;
      synchronizer.in.put(inCmplx);
      $write("Cycle %d: %m toSynchronizer data = ",cycle);
      cmplxWrite("("," + "," i)",fxptWrite(7),inCmplx);
      $display("");
   endrule

   Reg#(Bit#(16)) dataIdx <- mkReg(0);
   Reg#(Bool) compareReg <- mkReg(False);

   rule fromSynchronizer(True);
      let result <- synchronizer.out.get;
      let resultCmplx = result.data;
      let idx = dataIdx;
      let compare = compareReg;
      outCounter <= outCounter + 1;
      if (result.control.isNewPacket)
         begin
            idx = 0;
            compareReg <= True;
            compare = True;
            deq_fifo.enq(outCounter);
         end

      $write("Cycle %d: %m fromSynchronizer data = ", cycle);
      cmplxWrite("("," + ","i)",fxptWrite(7),resultCmplx);
      $display("");

      if (compare && idx < 1740 - 320)
        begin
          outData.enq(resultCmplx);
       end
      
      dataIdx <= idx + 1;
   endrule

   // This breaks if the synchronizer makes a mistake.
   rule compare;
     let actual = outData.first;
     outData.deq();

     FPComplex#(2,14) expected = inData.first;
     inData.deq;
     FPComplex#(2,14) diff = expected - actual;
 
     //$write("idx=%d", idx);
     $write("expected = ");
     cmplxWrite("("," + ","i)",fxptWrite(7),expected);
     $write(" diff = ");
     cmplxWrite("("," + ","i)",fxptWrite(7),diff);
     $display("");
   endrule
 
   
   rule missPacket(outCounter > expected_pos + 320);
      misses <= misses + 1;
      expected_sync_pos_fifo.deq();
      $display("Cycle %d: new packet detection fails at expected_position = %d", cycle, expected_pos);
   endrule
      
   rule detectNewPacket(expected_sync_pos_fifo.notEmpty() && deq_fifo.notEmpty());      
      let actual_pos = deq_fifo.first();
      let diff_is_positive = (actual_pos > expected_pos); // positive = late detection
      let diff_pos = diff_is_positive ? actual_pos - expected_pos : expected_pos - actual_pos;
      deq_fifo.deq();
      if (!diff_is_positive && diff_pos > 320) // a too early detection positive is false positive
         begin
            false <= false + 1;
            $display("Cycle %d: unexpected packet detected position = %d", cycle, actual_pos);
         end
      else
         begin
            detected <= detected + 1;
            expected_sync_pos_fifo.deq();
            $display("Cycle %d: new packet detected_position = %d, expected_position = %d, is_late_detection = %d, diff = %d ", cycle, actual_pos, expected_pos, diff_is_positive, diff_pos);
         end
   endrule
   
   // it is false postive if synchronizer detect something that is not expected
   rule falsePositive(deq_fifo.notEmpty() && !expected_sync_pos_fifo.notEmpty());
      false <= false + 1;
      deq_fifo.deq();
      $display("Cycle %d: unexpected packet detected position = %d", cycle, deq_fifo.first());
   endrule
   
   rule readCoarPow(True);
      $write("Cycle %d: readCoarPow = ", cycle);
      fxptWrite(7,statefulSynchronizer.coarPow);
      $display("");
   endrule
   
   // tick
   rule tick(True);
      cycle <= cycle + 1;
   endrule
   
   rule finishTest(cycle > 3000000);
      $display("Cycle %d: simulation ends, detection success = %d, misses = %d, false +v = %d",cycle,detected,misses,false);
      if (misses == 0 && false == 0)
         $display("PASS");
      else
         $display("FAIL");
      $finish();
   endrule
   
endmodule   



