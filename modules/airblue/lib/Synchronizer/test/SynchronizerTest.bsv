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

// import Channel::*;
// import DataTypes::*;
// import Interfaces::*;
// import Synchronizer::*;
// import Preambles::*;
// import SynchronizerLibrary::*;
// import FPComplex::*;
// import Controls::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_channel.bsh"

// to deal with the case where synchronizer may output some initialization junk samples, will try to adjust the expected position accordingly 
`define SyncPosAdjustment 11 

import "BDPI" nextRandData = 
    function Bit#(32) nextRandData();

interface PacketGenerator;
   interface Get#(Bit#(16))         nextLength; // start the next random packet, return packet length
   interface Get#(FPComplex#(2,14)) nextData;   // get the next data
endinterface

typedef enum{
   Idle = 0, // generator is idle
   Short = 1, // generator is generating short preamable
   Long = 2, // generator is generating long preamble
   Data = 3 // generator is generating data
} PacketGeneratorState deriving (Bits, Eq);

(* synthesize *)
module mkPacketGenerator (PacketGenerator);
   
   LFSR#(Bit#(16))            len_lfsr    <- mkLFSR_16();  // to generate random data length 
   LFSR#(Bit#(16))            i_lfsr      <- mkLFSR_16();  // to generate i of the sample
   LFSR#(Bit#(16))            q_lfsr      <- mkLFSR_16();  // to generate q of the sample
   Reg#(PacketGeneratorState) state       <- mkReg(Idle);  // the state of the current packetgenrator
   Reg#(Bit#(16))             counter     <- mkReg(0);     // no. samples output at this state so far
   Reg#(Bit#(7))              idx         <- mkReg(0);
   Reg#(Bool)                 initialized <- mkReg(False); // initialized the seed yet?

   let len = (len_lfsr.value() > maxBound - 320) ? maxBound : len_lfsr.value() + 320;
   
   rule initialization (!initialized);
      initialized <= True;
      len_lfsr.seed(16'h107a);
      i_lfsr.seed(16'h7c43);
      q_lfsr.seed(16'h5325);
   endrule
   
   interface Get nextLength;
      method ActionValue#(Bit#(16)) get() if (initialized && state == Idle);
         state <= Short;
         counter <= 1;
         idx <= 96; // starting with cyclic prefix pos
         return len;
      endmethod
   endinterface
   
   interface Get nextData;
      method ActionValue#(FPComplex#(2,14)) get() if (initialized && state != Idle);
         counter <= counter + 1;
         case (state)
            Short: begin
                      let short = getShortPreambles();
                      if (counter == 160) // get to next state
                         begin
                            state <= Long;
                            idx <= 96;
                         end
                      else
                         begin
                            idx <= idx + 1;
                         end
                      return short[idx];
                   end
            Long: begin
                     let long = getLongPreambles();
                     if (counter == 320) // get to the next state
                        begin
                           state <= Data;
                        end
                     else
                        begin
                           idx <= idx + 1;
                        end
                     return long[idx];
                  end
            Data: begin
                     i_lfsr.next();
                     q_lfsr.next();
                     FPComplex#(2,14) out_sample;
                     if (`RAND_DATA_FROM_C == 1)
                        begin
                           let out = nextRandData();
                           let outRel = truncate(out);
                           let outImg = tpl_1(split(out));
                           out_sample = cmplx(unpack(outRel), unpack(outImg));
                        end
                     else
                        begin
                           out_sample = cmplx(unpack(i_lfsr.value()), unpack(q_lfsr.value()));
                        end
                     if (counter == len) 
                        begin
                           len_lfsr.next();
                           state <= Idle;
                        end
                     return out_sample;
                  end
         endcase
      endmethod
   endinterface
      
endmodule 


(* synthesize *)
module [Module] mkStatefulSynchronizerInstance(StatefulSynchronizer#(2,14));
   let ifc <- exposeCBusIFC(mkStatefulSynchronizer); 
   let statefulSynchronizer = ifc.device_ifc;
   return statefulSynchronizer;
endmodule

   
module mkHWOnlyApplication (Empty);   
   let test <- mkSynchronizerTest();
endmodule
   
(* synthesize *)
module mkSynchronizerTest(Empty);
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
      inCounter <= inCounter - 1;
      channel.in.put(inCmplx);
   endrule

   rule toSynchronizer(True);
      FPComplex#(2,14) inCmplx <- channel.out.get(); 
      synchronizer.in.put(inCmplx);
      $write("Cycle %d: %m toSynchronizer data = ",cycle);
      cmplxWrite("("," + "," i)",fxptWrite(7),inCmplx);
      $display("");
   endrule

   rule fromSynchronizer(True);
      let result <- synchronizer.out.get;
      let resultCmplx = result.data;
      outCounter <= outCounter + 1;
      $write("Cycle %d: %m fromSynchronizer data = ", cycle);
      cmplxWrite("("," + ","i)",fxptWrite(7),resultCmplx);
      $display("");
      if (result.control.isNewPacket)
         begin
            deq_fifo.enq(outCounter);
         end
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
   
   rule finishTest(cycle > 300000);
      $display("Cycle %d: simulation ends, detection success = %d, misses = %d, false +v = %d",cycle,detected,misses,false);
      if (misses == 0 && false == 0)
         $display("PASS");
      else
         $display("FAIL");
      $finish();
   endrule
   
endmodule   



