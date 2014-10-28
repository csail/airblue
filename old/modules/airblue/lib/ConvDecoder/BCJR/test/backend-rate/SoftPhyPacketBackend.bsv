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

import ConfigReg::*;
import GetPut::*;
import Vector::*;
import Complex::*;
import FShow::*;
import FIFO::*;
import FIFOF::*;
import StmtFSM::*;
import FixedPoint::*;

// Local includes
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/librl_bsv_storage.bsh"

`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/airblue_convolutional_decoder_test_common.bsh"
`include "asim/provides/airblue_descrambler.bsh"
`include "asim/provides/airblue_softhint_avg.bsh"
`include "asim/provides/starter_service.bsh"

typedef Put#(DecoderMesg#(TXGlobalCtrl,24,ViterbiMetric)) ConvolutionalDecoderTestBackend;

module [CONNECTED_MODULE] mkConvolutionalDecoderTestBackend#(Viterbi#(RXGlobalCtrl, 24, 12) convolutionalDecoder) (ConvolutionalDecoderTestBackend);

   Connection_Send#(Bit#(64)) errorsC <- mkConnection_Send("airblue_packet_errors");
   Connection_Send#(Bit#(64)) totalC <- mkConnection_Send("airblue_packet_bits");
   Connection_Send#(Bit#(32)) hintC <- mkConnection_Send("airblue_packet_hint");

   FIFO#(Vector#(12, Bit#(12)))  outSoftPhyHintsQ <- mkSizedFIFO(256);
   SoftHintAvg softHintAvg <- mkSoftHintAvg;
   FIFOF#(Tuple2#(Bit#(32),Bit#(32))) actualBER <- mkFIFOF;
 
   // Pipeline elements
   let descrambler <- mkDescramblerInstance;

   Reg#(Bit#(12)) dec_cnt <- mkReg(0);
   Reg#(Bit#(12)) des_cnt <- mkReg(0);
   Reg#(Bit#(12)) out_cnt <- mkReg(0);
   Reg#(Bit#(12)) in_data <- mkReg(0);
   Reg#(Bit#(48)) cycle <- mkReg(0);
   Reg#(Bit#(12)) out_data <- mkReg(0);
   Reg#(Bit#(48)) total <- mkConfigReg(0); // total bits received

   Reg#(Bit#(32)) packet_errors <- mkReg(0);
   Reg#(Bit#(32)) packet_total <- mkReg(0);

   Reg#(Bit#(7)) dumpAddr <- mkReg(0);   

   rule putDescrambler(True);
      let mesg <- convolutionalDecoder.out.get;
      Maybe#(Bit#(7)) seed = tagged Invalid;

      // Need to extract 
      let softHints = tpl_2(unzip(mesg.data));
      let msgData = pack(tpl_1(unzip(mesg.data)));
      outSoftPhyHintsQ.enq(softHints);

      if (mesg.control.firstSymbol && des_cnt == 0)
         begin
           des_cnt <= mesg.control.length - 1;
           seed = tagged Valid magicConstantSeed;
         end
      else
         begin
            if (des_cnt > 0) 
               begin                   
                  des_cnt <= des_cnt - 1;
               end            
         end
      let rxDCtrl = RXDescramblerCtrl{seed: seed, bypass: 0};
      let rxGCtrl = mesg.control;
      let rxCtrl = RXDescramblerAndGlobalCtrl{descramblerCtrl: rxDCtrl, globalCtrl: rxGCtrl};

      descrambler.in.put(Mesg{control: rxCtrl, data: msgData});    
   endrule 

   // Becuase of the Lutram, we have to serialize get output.  Not the worst thing in the world
   // I don't like this magic number 12
   Reg#(Bit#(4)) bitIndex <- mkReg(11);
   FIFO#(ScramblerMesg#(RXDescramblerAndGlobalCtrl,12)) descMesgs <- mkSizedFIFO(512); // Probably need to buffer a whole packet
   
   rule transferData;
     let mesg <- descrambler.out.get;     
     descMesgs.enq(mesg); 
   endrule

   rule getOutput;
      let mesg = descMesgs.first();
      let expected_data = out_data + 1; 
      let diff = mesg.data ^ expected_data; // try to get the bits that are different

      let next_errors = packet_errors;
      let next_total = packet_total;

      Bool last = (out_cnt == 2 && bitIndex == 0);
      let hints = outSoftPhyHintsQ.first;
      let rate = mesg.control.globalCtrl.rate;

      if (out_cnt > 1)
        begin
          softHintAvg.in.put(SoftHintMesg {
             rate: unpack(pack(rate)), // EEEK! two definitions of rate
             hint: hints[bitIndex],
             isLast: last
          });

          if (diff[bitIndex] == 1)
             next_errors = packet_errors + 1;
          next_total = packet_total + 1;
        end

      if(bitIndex == 0) 
        begin
          descMesgs.deq();     
          outSoftPhyHintsQ.deq();
          bitIndex <= 11;

          if (out_cnt > 0)
            begin
              out_data <= out_data + 1;
              total <= total + 12;
            end

          if (out_cnt == 0 && mesg.control.globalCtrl.firstSymbol)
            begin
              out_data <= 1;
              out_cnt <= mesg.control.globalCtrl.length - 1;
              total <= total + 12;
            end
          else if (out_cnt > 0)
             out_cnt <= out_cnt - 1;
        end
      else
        begin
          bitIndex <= bitIndex - 1;
        end

      if (last)
        begin
          errorsC.send(extend(next_errors));
          totalC.send(extend(next_total));
          packet_errors <= 0;
          packet_total <= 0;
        end
      else
        begin
           packet_errors <= next_errors;
           packet_total <= next_total;
        end
   endrule
      
   rule sendPrediction;
     let predicted <- softHintAvg.out.get();
     FixedPoint#(16,16) value = fxptSignExtend(predicted);
     hintC.send(pack(value));
   endrule

   method Action put(DecoderMesg#(TXGlobalCtrl,24,ViterbiMetric) mesg);
      Bool push_zeros = False; 
      if (`DEBUG_CONV_DECODER_TEST == 1)
        begin
          $display("Depuncturer Out Mesg: fst_syn:%d, rate:%d, data:%b",mesg.control.firstSymbol, mesg.control.rate,mesg.data);
          $display("Depuncturer dec_cnt: %d", dec_cnt);
        end
      if (mesg.control.firstSymbol && dec_cnt == 0)
         begin
            dec_cnt <= mesg.control.length - 1;
         end
      else
         begin
            if (dec_cnt > 0)
               begin
                  dec_cnt <= dec_cnt - 1;
                  if (dec_cnt == 1) // last one
                     begin
                        push_zeros = True;
                     end
               end
            else
               begin
                  $display("Error! putViterbi should never decrement dec_cnt when its value is 0");
                  $finish;
               end
         end
     
      let rx_ctrl = RXGlobalCtrl{firstSymbol: mesg.control.firstSymbol,
                                 rate: mesg.control.rate,
                                 length: mesg.control.length,
                                 viterbiPushZeros: push_zeros};
      let new_mesg = Mesg{control: rx_ctrl, data:mesg.data};
      convolutionalDecoder.in.put(new_mesg); 
      if (`DEBUG_CONV_DECODER_TEST == 1)
         begin
            for(Integer i = 0; i < 24; i = i + 1)
               $display("ConvDecoder In %o",mesg.data[i]);
            //      $display("Depuncturer Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
         end

  endmethod

endmodule
