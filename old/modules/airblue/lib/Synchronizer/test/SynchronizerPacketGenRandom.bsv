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

import Complex::*;
import GetPut::*;
import LFSR::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"

import "BDPI" nextRandData = 
    function Bit#(32) nextRandData();

interface PacketGenerator;
   method Bool isData;
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

   method Bool isData;
      return counter > 320;
   endmethod

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
