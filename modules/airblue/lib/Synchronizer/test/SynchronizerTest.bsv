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
import FIFO::*;
import FixedPoint::*;
import GetPut::*;
import LFSR::*;
import RegFile::*;
import Vector::*;

// import DataTypes::*;
// import Interfaces::*;
// import Synchronizer::*;
// //import Preambles::*;
// import SynchronizerLibrary::*;
// import FPComplex::*;
// import Controls::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_channel.bsh"


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
   Reg#(Bool)                 initialized <- mkReg(False); // initialized the seed yet?

   let len = (len_lfsr.value() > maxBound - 256) ? maxBound : len_lfsr.value() + 256;
   
   rule initialization (!initialized);
      initialized <= True;
      len_lfsr.seed(16'h107a);
      i_lfsr.seed(16'h7c43);
      q_lfsr.seed(16'h5325);
   endrule
   
   interface Get nextLength;
      method ActionValue#(Bit#(16)) get() if (initialized && state == Idle);
         state <= Short;
         counter <= 0;
         return len;
      endmethod
   endinterface
   
   interface Get nextData;
      method ActionValue#(FPComplex#(2,14)) get() if (initialized && state != Idle);
         case (state)
            Short: begin
                      let short = getShortPreambles();
                      if (counter == 127) // get to next state
                         begin
                            counter <= 0;
                            state <= Long;
                         end
                      else
                         counter <= counter + 1;
                      return short[counter];
                   end
            Long: begin
                     let long = getLongPreambles();
                     if (counter == 127) // get to the next state
                        begin
                           counter <= 0;
                           state <= Data;
                        end
                     else
                        counter <= counter + 1;
                     return long[counter];
                  end
            Data: begin
                     i_lfsr.next();
                     q_lfsr.next();
                     if (counter == len-257) // minus 256 preamble
                        begin
                           counter <= 0;
                           len_lfsr.next();
                           state <= Idle;
                        end
                     else
                        counter <= counter + 1;
                     return cmplx(unpack(i_lfsr.value()),unpack(q_lfsr.value()));
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
   
   Reg#(Bit#(32))  expected_sync_pos <- mkReg(256); // the next expected synchronization position, the first one should start at 256th (assuming 0 is the 1st output)
   FIFO#(Bit#(32)) expected_sync_pos_fifo <- mkSizedFIFO(4); // check whether the expected synchronization position match  
   
   // constant
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
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
            expected_sync_pos_fifo.deq();
            $display("Cycle %d: new packet detected at position %d, expected position %d", cycle, outCounter, expected_sync_pos_fifo.first());
         end
   endrule
   
   rule readCoarPow(True);
      $write("Cycle %d: readCoarPow = ", cycle);
      fxptWrite(7,statefulSynchronizer.coarPow);
      $display("");
   endrule
   
   // tick
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 10000)
	 $finish();
   endrule
     
endmodule   



