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
import Connectable::*;

// Local includes
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/provides/fpga_components.bsh"

`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/airblue_fft.bsh"
`include "asim/provides/airblue_convolutional_encoder.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/airblue_convolutional_decoder_test_common.bsh"
`include "asim/provides/airblue_convolutional_decoder_backend.bsh"
`include "asim/provides/airblue_mapper.bsh"
`include "asim/provides/airblue_demapper.bsh"
`include "asim/provides/airblue_puncturer.bsh"
`include "asim/provides/airblue_depuncturer.bsh"
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/airblue_scrambler.bsh"
`include "asim/provides/airblue_descrambler.bsh"
`include "asim/provides/airblue_transactor.bsh"
`include "asim/rrr/client_stub_SIMPLEHOSTCONTROLRRR.bsh"


module [CONNECTED_MODULE] mkConvolutionalDecoderTest (Empty);

   UserClock frontend <- mkUserClock_Ratio(`MODEL_CLOCK_FREQ,2,5);

   let convolutionalDecoderTestBackend <- mkConvolutionalDecoderTestBackend();
   let convolutionalDecoderTestFrontend <- mkConvolutionalDecoderTestFrontend(clocked_by frontend.clk, reset_by frontend.rst);

endmodule

module [CONNECTED_MODULE] mkConvolutionalDecoderTestFrontend (Empty);

   // host control
   ClientStub_SIMPLEHOSTCONTROLRRR client_stub <- mkClientStub_SIMPLEHOSTCONTROLRRR;

   // state elements
   let conv_encoder <- mkConvEncoderInstance;
   let puncturer <- mkPuncturerInstance;
   let mapper <- mkMapperInstance;
   let demapper <- mkDemapperInstance;
   let depuncturer <- mkDepuncturerInstance;
   let ifft <- mkIFFTInstance;
   let fft  <- mkFFTInstance;
   let scrambler <- mkScramblerInstance;
   Transactor#(Mesg#(TXGlobalCtrl, Vector#(64,FPComplex#(2,14))) , 
               Mesg#(TXGlobalCtrl, Vector#(64,FPComplex#(2,14)))) transactor <- mkTransactor;

   // instantiate backend, plumbing 

   Connection_Send#(DecoderMesg#(TXGlobalCtrl,24,ViterbiMetric)) demapperOutput <- mkConnection_Send("conv_decoder_test_output"); 


   // channel
   FIFO#(TXGlobalCtrl) ctrlFifo <- mkSizedFIFO(256);
   let channel <- mkStreamChannel;

   // runtime parameters
   Reg#(Rate) rate <- mkRegU;
   Reg#(Bool) initialized <- mkReg(False);
   Reg#(Bool) ranFSM <- mkReg(False);
   Reg#(Bit#(12)) length <- mkReg(1);

   Reg#(TXGlobalCtrl) ctrl <- mkReg(TXGlobalCtrl{firstSymbol:False,
						 rate:R0,
                                                 length: 1,
                                                 endSimulation: False});
  
   Reg#(Bit#(34)) finish_packets <- mkReg(0);
   Reg#(Bit#(34)) sent_packets <- mkReg(0);
   Reg#(Bit#(12)) counter <- mkReg(0);
   Reg#(Bit#(12)) scr_cnt <- mkReg(0);
   Reg#(Bit#(12)) dec_cnt <- mkReg(0);
   Reg#(Bit#(12)) in_data <- mkReg(0);


   Stmt initStmt = (seq
      client_stub.makeRequest_GetRate(0);
      action
         let resp <- client_stub.getResponse_GetRate();
         rate <= unpack(truncate(resp));
      endaction
      client_stub.makeRequest_GetPacketSize(0);
      action
         let resp <- client_stub.getResponse_GetPacketSize();
         length <= truncate(resp);
      endaction
      client_stub.makeRequest_GetFinishCycles(0);
      action
         let resp <- client_stub.getResponse_GetFinishCycles();
         finish_packets <= truncate(resp);
      endaction
      initialized <= True;
   endseq);

   FSM initFSM <- mkFSM(initStmt);

   rule init (!initialized && !ranFSM);
      initFSM.start();
      ranFSM <= True;
   endrule
   
   let end_simulation = finish_packets == sent_packets + 1;

   rule putNewRate(counter == 0 && initialized && finish_packets > sent_packets);
//      let new_ctrl = nextCtrl(ctrl, rate, 144*length,end_simulation);
      let new_ctrl = nextCtrl(ctrl, rate, length,end_simulation);
//      $display("DecoderTests new packet r %d l %d", rate, 144*length);
      $display("DecoderTests new packet r %d l %d", rate, length);
      let new_data = in_data + 1;
      let bypass_mask = 0; // no bypass
      let seed = tagged Valid magicConstantSeed;
      let fst_symbol = True;
      let new_mesg = makeMesg(bypass_mask, seed, fst_symbol, new_ctrl.rate, 
                              new_ctrl.length, end_simulation, new_data);
      let new_counter = new_ctrl.length - 1;
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Testbench sets counter to %d", new_ctrl.length-1);
      ctrl <= new_ctrl;
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("ConvEncoder Input: %h", new_data);
      in_data <= new_data;
      counter <= new_counter;
      scrambler.in.put(new_mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Conv Encoder In Mesg: rate:%d, data:%b, counter:%d",new_ctrl.rate,new_data,new_counter);
   endrule

   rule putNewData(counter > 0);
      let new_ctrl = ctrl;
      let new_data = in_data + 1;
      let bypass_mask = 0; // no bypass
      let seed = tagged Invalid; // no new seed for scrambler
      let new_mesg = makeMesg(bypass_mask, seed, False, new_ctrl.rate, new_ctrl.length, end_simulation, new_data);
      let new_counter = counter - 1;
      in_data <= new_data;
      counter <= new_counter;
      if(new_counter == 0) 
        begin
          sent_packets <= sent_packets + 1;
        end

      scrambler.in.put(new_mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         begin
            $display("ConvEncoder Input: %h", new_data);
            $display("Conv Encoder In Mesg: rate:%d, data:%b, counter:%d",new_ctrl.rate,new_data,new_counter);
         end
   endrule
   
   rule putConvEncoder(!transactor.tx_stall());
      let mesg <- scrambler.out.get;
      if (mesg.control.firstSymbol) 
         begin
            scr_cnt <= mesg.control.length - 1;
            conv_encoder.in.put(mesg);
         end
      else
         begin
            scr_cnt <= scr_cnt - 1;
            if (scr_cnt == 1) // last one, zero out data;
               begin
                  conv_encoder.in.put(Mesg{control: mesg.control, data: 0});
               end
            else
               begin
                  conv_encoder.in.put(mesg);                  
               end
         end
   endrule
   
   rule putPuncturer(!transactor.tx_stall());
      let mesg <- conv_encoder.out.get;
      puncturer.in.put(mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Conv Encoder Out Mesg: fst_sym:%d, rate:%d, data:%b",mesg.control.firstSymbol, mesg.control.rate,mesg.data);
   endrule
   
   rule putMapper(!transactor.tx_stall());
      let mesg <- puncturer.out.get;
      mapper.in.put(mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Puncturer Out Mesg: fst_sym:%d, rate:%d, data:%b",mesg.control.firstSymbol, mesg.control.rate,mesg.data);
   endrule
   
   rule putIFFT (!transactor.tx_stall());
     let mesg <- mapper.out.get;
     ifft.in.put(Mesg{control:mesg.control,
                      data:append(mesg.data,replicate(0))});
   endrule

   rule getIFFT (!transactor.tx_stall());
      let mesg <- ifft.out.get();
      transactor.tx_xactor_in.put(mesg);
   endrule
   
   rule getTX (channel.notFull(64));
      Mesg#(TXGlobalCtrl, Vector#(64,FPComplex#(2,14))) mesg <- transactor.tx_xactor_out.get();
      ctrlFifo.enq(mesg.control);
      channel.enq(64, append(mesg.data, ?));
   endrule

   rule putFFT (channel.notEmpty(64));
      transactor.rx_xactor_in.put(Mesg {
         control: ctrlFifo.first,
         data: take(channel.first)
      });

      ctrlFifo.deq();
      channel.deq(64);
   endrule
   
   rule getRX (!transactor.rx_stall());
      let mesg <- transactor.rx_xactor_out.get();
      fft.in.put(mesg);
   endrule

   rule putDemapper(!transactor.rx_stall());
      let freqDomain <- fft.out.get;
      demapper.in.put(Mesg{control:freqDomain.control,
                           data:take(freqDomain.data)});
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("FFT Out Mesg: fst_sym:%d, rate:%d, end_sim: %d ",freqDomain.control.firstSymbol, freqDomain.control.rate, freqDomain.control.endSimulation);
   endrule
   
   rule putDepuncturer(!transactor.rx_stall());
      let mesg <- demapper.out.get;
      depuncturer.in.put(mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Demapper Out Mesg: fst_sym:%d, rate:%d, data:%b",mesg.control.firstSymbol, mesg.control.rate,mesg.data);
   endrule


   rule sendBackend(!transactor.rx_stall());
     let data <- depuncturer.out.get();
     demapperOutput.send(data);
   endrule

endmodule
