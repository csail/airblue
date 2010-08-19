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
import Clocks::*;

// Local includes
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/provides/soft_clocks.bsh"

`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/airblue_convolutional_decoder.bsh"
`include "asim/provides/airblue_convolutional_decoder_test_common.bsh"
`include "asim/provides/airblue_descrambler.bsh"
`include "asim/provides/starter_service.bsh"
`include "asim/rrr/client_stub_SOFT_PHY_BUCKET_RRR.bsh"

typedef Empty ConvolutionalDecoderTestBackend;

module mkConvDecoderInstance(Viterbi#(RXGlobalCtrl,24,12));
   Viterbi#(RXGlobalCtrl,24,12) decoder;
   decoder <- mkConvDecoder(viterbiMapCtrl);
   return decoder;
endmodule


module [CONNECTED_MODULE] mkConvolutionalDecoderTestBackend (Empty);

   UserClock viterbi <- mkSoftClock(50);

   // Starter service sink
   Connection_Send#(Bit#(8)) endSim <- mkConnection_Send("vdev_starter_finish_run",clocked_by viterbi.clk, reset_by viterbi.rst);
   Connection_Receive#(DecoderMesg#(TXGlobalCtrl,24,ViterbiMetric)) demapperInput <- mkConnection_Receive("conv_decoder_test_output",clocked_by viterbi.clk, reset_by viterbi.rst); 

   // Host stub
   ClientStub_SOFT_PHY_BUCKET_RRR backend_stub <- mkClientStub_SOFT_PHY_BUCKET_RRR(clocked_by viterbi.clk, reset_by viterbi.rst);

   // runtime parameters
   Reg#(Bool) doneDomain <- mkReg(False,clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bool) simulationComplete <- mkReg(False,clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bool) done <- mkReg(False,clocked_by viterbi.clk, reset_by viterbi.rst);

   Reg#(TXGlobalCtrl) ctrl <- mkReg(TXGlobalCtrl{firstSymbol:False,
						 rate:R0});
 
   FIFO#(Vector#(12, Bit#(12)))  outSoftPhyHintsQ <- mkSizedFIFO(256, clocked_by viterbi.clk, reset_by viterbi.rst);
   FIFO#(DecoderMesg#(TXGlobalCtrl,24,ViterbiMetric)) mesgInQ <- mkFIFO(clocked_by viterbi.clk, reset_by viterbi.rst);
   FIFO#(Tuple3#(Bit#(12),Bit#(48),Bit#(48))) statOutQ <- mkFIFO(clocked_by viterbi.clk, reset_by viterbi.rst);

   // Pipeline elements
   let descrambler <- mkDescramblerInstance(clocked_by viterbi.clk, 
                                            reset_by viterbi.rst);

   let convolutionalDecoder <- mkConvDecoderInstance(clocked_by viterbi.clk, reset_by viterbi.rst);

   Reg#(Bit#(12)) dec_cnt <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bit#(12)) des_cnt <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bit#(12)) out_cnt <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bit#(12)) in_data <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bit#(48)) cycle <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bit#(12)) out_data <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);
   Reg#(Bit#(48)) errors <- mkConfigReg(0, clocked_by viterbi.clk, reset_by viterbi.rst); // accumulated errors
   Reg#(Bit#(48)) total <- mkConfigReg(0, clocked_by viterbi.clk, reset_by viterbi.rst); // total bits received
   Reg#(Bit#(12)) dumpAddrDomain <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);   
   Reg#(Bit#(12)) dumpAddr <- mkReg(0, clocked_by viterbi.clk, reset_by viterbi.rst);   

   // Because the maximum distance appears to be limited in practice, don't bother collecting large results
   LUTRAM#(Bit#(12),Bit#(48)) errorCounts <- mkLUTRAM(0, clocked_by viterbi.clk, reset_by viterbi.rst);
   LUTRAM#(Bit#(12),Bit#(48)) totalCounts <- mkLUTRAM(0, clocked_by viterbi.clk, reset_by viterbi.rst);


   
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
   Reg#(Bit#(4)) bitIndex <- mkReg(11,clocked_by viterbi.clk, reset_by viterbi.rst);
   FIFO#(ScramblerMesg#(RXDescramblerAndGlobalCtrl,12)) descMesgs <- mkSizedFIFO(512,clocked_by viterbi.clk, reset_by viterbi.rst); // Probably need to buffer a whole packet
   
   rule transferData;
     let mesg <- descrambler.out.get;     
     descMesgs.enq(mesg); 
   endrule
   
   rule drainLastPacket(descMesgs.first().control.globalCtrl.endSimulation);
      simulationComplete <= True;
      descMesgs.deq();     
      outSoftPhyHintsQ.deq();
   endrule


   rule getOutput(!descMesgs.first().control.globalCtrl.endSimulation);
      let mesg = descMesgs.first();
      let expected_data = out_data + 1; 
      let diff = mesg.data ^ expected_data; // try to get the bits that are different

      if (out_cnt > 1)
        begin
          let hint = outSoftPhyHintsQ.first[bitIndex];
          if(diff[bitIndex] == 1)
             begin
               errorCounts.upd(hint, errorCounts.sub(hint) + 1);
             end

          totalCounts.upd(hint, totalCounts.sub(hint) + 1);
         end

      if(bitIndex == 0) 
        begin          
          descMesgs.deq();     
          outSoftPhyHintsQ.deq();
          bitIndex <= 11;
          // All the stuff that we used to do in a single cycle, we'll do 
          // here 
    
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
        end
      else
        begin
          bitIndex <= bitIndex - 1;
        end
   endrule
      
   //handle polling the rams
   // This rule may well require a scheduling pragma
   rule handleExternalReqsTopDomain(simulationComplete && !doneDomain);
     statOutQ.enq(tuple3(dumpAddrDomain,
                         errorCounts.sub(dumpAddrDomain),
                         totalCounts.sub(dumpAddrDomain)));
     if(dumpAddrDomain + 1 == 0)
       begin
         doneDomain <= True;
       end
     dumpAddrDomain <= dumpAddrDomain + 1;
   endrule
 
   rule handleExternalReqsTop(!done);
     statOutQ.deq();
     backend_stub.makeRequest_SendBucket(zeroExtend(tpl_1(statOutQ.first)),
                                         zeroExtend(tpl_2(statOutQ.first)),
                                         zeroExtend(tpl_3(statOutQ.first)));

     if(dumpAddr + 1 == 0)
       begin
         done <= True;
       end
     dumpAddr <= dumpAddr + 1;
    
   endrule

   rule drainResps;
     let dummy <- backend_stub.getResponse_SendBucket();
   endrule

   // this will probably work because we are dumping a lot of data.  
   rule handleExternalReqs(done);
     endSim.send(0);
   endrule

   rule domainInput;
      mesgInQ.deq;
      Bool push_zeros = False; 
      if (`DEBUG_CONV_DECODER_TEST == 1)
        begin
          $display("Depuncturer Out Mesg: fst_syn:%d, rate:%d, data:%b",mesgInQ.first.control.firstSymbol, mesgInQ.first.control.rate,mesgInQ.first.data);
          $display("Depuncturer dec_cnt: %d", dec_cnt);
        end
      if (mesgInQ.first.control.firstSymbol && dec_cnt == 0)
         begin
            dec_cnt <= mesgInQ.first.control.length - 1;
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
     
      let rx_ctrl = RXGlobalCtrl{firstSymbol: mesgInQ.first.control.firstSymbol,
                                 rate: mesgInQ.first.control.rate,
                                 length: mesgInQ.first.control.length,
                                 viterbiPushZeros: push_zeros,
                                 endSimulation: mesgInQ.first.control.endSimulation};
      let new_mesg = Mesg{control: rx_ctrl, data:mesgInQ.first.data};
      convolutionalDecoder.in.put(new_mesg); 
      if (`DEBUG_CONV_DECODER_TEST == 1)
         begin
            for(Integer i = 0; i < 24; i = i + 1)
               $display("ConvDecoder In %o",new_mesg.data[i]);
            //      $display("Depuncturer Out Mesg: rate:%d, data:%b",mesgInQ.first.control.rate,mesgInQ.first.data);
         end

   endrule


   rule inputValue;
      demapperInput.deq();
      mesgInQ.enq(demapperInput.receive());
   endrule

endmodule
