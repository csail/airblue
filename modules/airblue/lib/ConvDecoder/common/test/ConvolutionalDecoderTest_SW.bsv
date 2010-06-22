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
`include "asim/provides/airblue_host_control.bsh"


module [CONNECTED_MODULE] mkConvolutionalDecoderTest#(Viterbi#(RXGlobalCtrl, 24, 12) convolutionalDecoder) (Empty);

   // host control
   mkHostControl();

   // state elements
   let conv_encoder <- mkConvEncoderInstance;
   let puncturer <- mkPuncturerInstance;
   let mapper <- mkMapperInstance;
   let demapper <- mkDemapperInstance;
   let depuncturer <- mkDepuncturerInstance;
   let firstCtrl =  TXGlobalCtrl{firstSymbol:False, rate:R0};
   let ifft <- mkIFFTInstance;
   let fft  <- mkFFTInstance;
   let scrambler <- mkScramblerInstance;

   // instantiate backend 

   let convolutionalDecoderTestBackend <- mkConvolutionalDecoderTestBackend(convolutionalDecoder);

   // channel
   FIFO#(TXGlobalCtrl) ctrlFifo <- mkSizedFIFO(256);
   let channel <- mkStreamChannel;

   // runtime parameters
   Connection_Receive#(Rate) rateQ <- mkConnection_Receive("airblue_rate");
   Connection_Receive#(PhyPacketLength) lengthQ <- mkConnection_Receive("airblue_packet_size");

   Reg#(TXGlobalCtrl) ctrl <- mkReg(TXGlobalCtrl{firstSymbol:False,
						 rate:R0});

   Reg#(Bit#(12)) counter <- mkReg(0);
   Reg#(Bit#(12)) scr_cnt <- mkReg(0);
   Reg#(Bit#(12)) dec_cnt <- mkReg(0);
   Reg#(Bit#(12)) in_data <- mkReg(0);
   
   rule putNewRate(counter == 0);
      let rate = rateQ.receive();
      let length = lengthQ.receive();
      rateQ.deq();
      lengthQ.deq();

      let new_ctrl = nextCtrl(ctrl, rate, 144*length);
      $display("DecoderTests new packet r %d l %d", rate, 144*length);
      let new_data = 1;
      let bypass_mask = 0; // no bypass
      let seed = tagged Valid magicConstantSeed;
      let new_mesg = makeMesg(bypass_mask, seed, True, new_ctrl.rate, new_ctrl.length, new_data);
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
      let new_mesg = makeMesg(bypass_mask, seed, False, new_ctrl.rate, new_ctrl.length, new_data);
      let new_counter = counter - 1;
      in_data <= new_data;
      counter <= new_counter;
      scrambler.in.put(new_mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         begin
            $display("ConvEncoder Input: %h", new_data);
            $display("Conv Encoder In Mesg: rate:%d, data:%b, counter:%d",new_ctrl.rate,new_data,new_counter);
         end
   endrule
   
   rule putConvEncoder(True);
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
   
   rule putPuncturer(True);
      let mesg <- conv_encoder.out.get;
      puncturer.in.put(mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Conv Encoder Out Mesg: fst_sym:%d, rate:%d, data:%b",mesg.control.firstSymbol, mesg.control.rate,mesg.data);
   endrule
   
   rule putMapper(True);
      let mesg <- puncturer.out.get;
      mapper.in.put(mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Puncturer Out Mesg: fst_sym:%d, rate:%d, data:%b",mesg.control.firstSymbol, mesg.control.rate,mesg.data);
   endrule
   
   rule putIFFT;
     let mesg <- mapper.out.get;
     ifft.in.put(Mesg{control:mesg.control,
                      data:append(mesg.data,replicate(0))});
   endrule

   rule getIFFT (channel.notFull(64));
      Mesg#(TXGlobalCtrl, Vector#(64,FPComplex#(2,14))) mesg <- ifft.out.get();
      ctrlFifo.enq(mesg.control);
      channel.enq(64, append(mesg.data, ?));
   endrule

   rule putFFT (channel.notEmpty(64));
      fft.in.put(Mesg {
         control: ctrlFifo.first,
         data: take(channel.first)
      });

      ctrlFifo.deq();
      channel.deq(64);
   endrule

   rule putDemapper(True);
      let freqDomain <- fft.out.get;
      demapper.in.put(Mesg{control:freqDomain.control,
                           data:take(freqDomain.data)});
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("FFT Out Mesg: fst_sym:%d, rate:%d, data:%h",freqDomain.control.firstSymbol, freqDomain.control.rate,freqDomain.data);
   endrule
   
   rule putDepuncturer(True);
      let mesg <- demapper.out.get;
      depuncturer.in.put(mesg);
      if (`DEBUG_CONV_DECODER_TEST == 1)
         $display("Demapper Out Mesg: fst_sym:%d, rate:%d, data:%b",mesg.control.firstSymbol, mesg.control.rate,mesg.data);
   endrule


   mkConnection(depuncturer.out, convolutionalDecoderTestBackend);

endmodule
