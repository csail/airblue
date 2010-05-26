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
import StmtFSM::*;

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
`include "asim/provides/starter_service.bsh"
`include "asim/rrr/client_stub_SOFT_PHY_BUCKET_RRR.bsh"

typedef Put#(DecoderMesg#(TXGlobalCtrl,24,ViterbiMetric)) ConvolutionalDecoderTestBackend;

module [CONNECTED_MODULE] mkConvolutionalDecoderTestBackend#(Viterbi#(RXGlobalCtrl, 24, 12) convolutionalDecoder, ClientStub_SIMPLEHOSTCONTROLRRR client_stub) (ConvolutionalDecoderTestBackend);

   // Starter service sink
   Connection_Send#(Bit#(8)) endSim <- mkConnection_Send("vdev_starter_finish_run");

   // Host stub
   ClientStub_SOFT_PHY_BUCKET_RRR backend_stub <- mkClientStub_SOFT_PHY_BUCKET_RRR;

   // runtime parameters
   Reg#(Rate) rate <- mkRegU;
   Reg#(Bit#(48)) finishTime <- mkRegU;
   Reg#(Bool) done <- mkReg(False);
   Reg#(Bool) initialized <- mkReg(False);

   Reg#(TXGlobalCtrl) ctrl <- mkReg(TXGlobalCtrl{firstSymbol:False,
						 rate:R0});
 
   FIFO#(Vector#(12, Bit#(12)))  outSoftPhyHintsQ <- mkSizedFIFO(256);
 
   // Pipeline elements
   let descrambler <- mkDescramblerInstance;

   Reg#(Bit#(12)) dec_cnt <- mkReg(0);
   Reg#(Bit#(12)) des_cnt <- mkReg(0);
   Reg#(Bit#(12)) out_cnt <- mkReg(0);
   Reg#(Bit#(12)) in_data <- mkReg(0);
   Reg#(Bit#(48)) cycle <- mkReg(0);
   Reg#(Bit#(12)) out_data <- mkReg(0);
   Reg#(Bit#(48)) errors <- mkConfigReg(0); // accumulated errors
   Reg#(Bit#(48)) total <- mkConfigReg(0); // total bits received
   Reg#(Bit#(7)) dumpAddr <- mkReg(0);   

   // Because the maximum distance appears to be limited in practice, don't bother collecting large results
   LUTRAM#(Bit#(7),Bit#(48)) errorCounts <- mkLUTRAM(0);
   LUTRAM#(Bit#(7),Bit#(48)) totalCounts <- mkLUTRAM(0);

   Stmt initStmt = (seq
      client_stub.makeRequest_GetFinishCycles(0);
      action
         let resp <- client_stub.getResponse_GetFinishCycles();
         finishTime <= truncate(resp);
      endaction
      initialized <= True;
   endseq);

   FSM initFSM <- mkFSM(initStmt);

   rule init (!initialized);
      initFSM.start();
   endrule
   
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

   rule sinkOutput(total >= finishTime);
     descMesgs.deq();     
     outSoftPhyHintsQ.deq();
   endrule

   rule getOutput(total < finishTime);
      if(bitIndex == 0) 
        begin
          descMesgs.deq();     
          outSoftPhyHintsQ.deq();
          bitIndex <= 11;
        end
      else
        begin
          bitIndex <= bitIndex - 1;
        end

      let mesg = descMesgs.first();
      let expected_data = out_data + 1; 
      let diff = mesg.data ^ expected_data; // try to get the bits that are different
      
      if(diff[bitIndex] == 1)
        begin
          errorCounts.upd(truncate(outSoftPhyHintsQ.first[bitIndex]), errorCounts.sub(truncate(outSoftPhyHintsQ.first[bitIndex])) + 1);
        end

      totalCounts.upd(truncate(outSoftPhyHintsQ.first[bitIndex]), totalCounts.sub(truncate(outSoftPhyHintsQ.first[bitIndex])) + 1);

      let no_error_bits = countOnes(diff); // one = error bit
      if (mesg.control.globalCtrl.firstSymbol && out_cnt == 0)
         begin
            out_cnt <= mesg.control.globalCtrl.length - 1;
            errors <= errors + zeroExtend(pack(no_error_bits));
            total <= total + 12;
            out_data <= out_data + 1;
            if (`DEBUG_CONV_DECODER_TEST == 1)
               begin
                  for(Integer i = 0; i < 12; i = i + 1)
                     begin
                  //            $display("Expected %b",expected_data[i]);
                        $display("ConvolutionalDecoder Out %b expected %b error %b",mesg.data[i],expected_data[i],mesg.data[i]!=expected_data[i]);
                     end
                  $display("Cycle: %d ConvolutionalDecoder Out Mesg: rate:%d, data:%b, no_error_bits: %d",cycle,mesg.control.globalCtrl.rate,mesg.data,no_error_bits);
               end
         end
      else
         begin
            if (out_cnt > 0)
               begin
                  out_cnt <= out_cnt - 1;
                  out_data <= out_data + 1;
                  `ifdef SOFT_PHY_HINTS
                     if(`DEBUG_CONV_DECODER_TEST == 1 && out_cnt == 1) 
                       begin
                         $display("EOP");
                       end
                  `endif
                  if (out_cnt > 1) // ignore the last data because of the zeroing of data to push state back to 0
                     begin
                        errors <= errors + zeroExtend(pack(no_error_bits));
                        total <= total + 12;
                        if (`DEBUG_CONV_DECODER_TEST == 1)
                           begin
                              for(Integer i = 0; i < 12; i = i + 1)
                                 begin
                                    //            $display("Expected %b",expected_data[i]);
                                    $display("ConvolutionalDecoder Out %b expected %b error %b",mesg.data[i],expected_data[i],mesg.data[i]!=expected_data[i]);
                                 end
                              $display("Cycle: %d ConvolutionalDecoder Out Mesg: rate:%d, data:%b, no_error_bits: %d",cycle,mesg.control.globalCtrl.rate,mesg.data,no_error_bits);
                           end
                     end
               end
         end
   endrule
      
   //handle polling the rams
   // This rule may well require a scheduling pragma
   rule handleExternalReqsTop(total >= finishTime && initialized && !done);
     //$display("Dumping bucket %d", dumpAddr);
     backend_stub.makeRequest_SendBucket(zeroExtend(dumpAddr),zeroExtend(errorCounts.sub(dumpAddr)),zeroExtend(totalCounts.sub(dumpAddr)));
     if(dumpAddr + 1 == 0)
       begin
         done <= True;
       end
     dumpAddr <= dumpAddr + 1;
   endrule
 
   rule drainResps;
     let dummy <- backend_stub.getResponse_SendBucket();
     //$display("Dumped bucket %d", dumpAddr);
   endrule

   // this will probably work because we are dumping a lot of data.  
   rule handleExternalReqs(done);
     $display("Sending done, total %d error %d", total,errors);
     endSim.send(0);
   endrule

   method Action put(DecoderMesg#(TXGlobalCtrl,24,ViterbiMetric) mesg) if(initialized);
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
