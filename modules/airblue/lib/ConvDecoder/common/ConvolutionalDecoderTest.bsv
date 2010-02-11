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

import Controls::*;
import ConfigReg::*;
import DataTypes::*;
import GetPut::*;
import Interfaces::*;
import Depuncturer::*;
import Vector::*;
import Mapper::*;
import Demapper::*;
import Puncturer::*;
import Viterbi::*;
import ConvEncoder::*;
import FFTIFFT::*;
import FPComplex::*;
import Complex::*;

// testing wifi setting
`define isDebug True // uncomment this line to display error

import "BDPI" addError = 
       function Bit#(24) addError();

import "BDPI" addNoise = 
       function Bit#(32) addNoise(Bit#(16) rel, Bit#(16) img, Bit#(32) rot, Bit#(32) res); 

import "BDPI" getConvOutBER =
       function Bit#(7) getConvOutBER();       
       
import "BDPI" nextRate = 
       function Rate nextRate();      
       
import "BDPI" viterbiMapCtrl = 
       function Bool viterbiMapCtrl(TXGlobalCtrl ctrl);
             
import "BDPI" finishTime =
       function Bit#(32) finishTime();

// Global Parameters:
typedef enum {
   R0,  // BPSK 1/2
   R1,  // BPSK 3/4
   R2,  // QPSK 1/2
   R3,  // QPSK 3/4
   R4,  // 16-QAM 1/2
   R5,  // 16-QAM 3/4
   R6,  // 64-QAM 2/3
   R7   // 64-QAM 3/4
} Rate deriving(Eq, Bits);

// may be an extra field for DL: sendPremable
typedef struct {
   Bool       firstSymbol; 
   Rate       rate;
} TXGlobalCtrl deriving(Eq, Bits);

function TXGlobalCtrl nextCtrl(TXGlobalCtrl ctrl);
   Rate new_rate = nextRate;
   return TXGlobalCtrl{ firstSymbol: False, rate: new_rate};
endfunction

function Bit#(16) getNewCounter(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: 1;  // (24/12)-1
	     R1: 2;  // (36/12)-1
	     R2: 3;  // (48/12)-1
	     R3: 5;  // (72/12)-1
	     R4: 7;  // (96/12)-1
	     R5: 11; // (144/12)-1
	     R6: 15; // (192/12)-1
	     R7: 17; // (216/12)-1
	  endcase;
endfunction

function PuncturerCtrl puncturerMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: Half;
	     R1: ThreeFourth;
	     R2: Half;
	     R3: ThreeFourth;
	     R4: Half;
	     R5: ThreeFourth;
	     R6: TwoThird;
	     R7: ThreeFourth;
	  endcase; // case(rate)
endfunction // Bit  

function Bit#(3) p1 (Bit#(4) x);
   return x[2:0];
endfunction // Bit
   
function Bit#(4) p2 (Bit#(6) x);
   return {x[5],x[2:0]};
endfunction // Bit

// not used in WiFi   
function Bit#(6) p3 (Bit#(10) x);
   return 0;
endfunction // Bit

function DepunctData#(4) dp1 (DepunctData#(3) x);
   DepunctData#(4) out_vec = replicate(4);
   out_vec[0] = x[0];
   out_vec[1] = x[1];
   out_vec[2] = x[2];
   return out_vec;
endfunction // Bit
   
function DepunctData#(6) dp2 (DepunctData#(4) x);
   DepunctData#(6) out_vec = replicate(4);
   out_vec[0] = x[0];
   out_vec[1] = x[1];
   out_vec[2] = x[2];
   out_vec[5] = x[3];
   return out_vec;
endfunction // Bit

// not used in wifi   
function DepunctData#(10) dp3 (DepunctData#(6) x);
   DepunctData#(10) out_vec = replicate(4);
   return out_vec;
endfunction // Bit

// used for both interleaver, mapper
function Modulation modulationMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: BPSK;
	     R1: BPSK;
	     R2: QPSK;
	     R3: QPSK;
	     R4: QAM_16;
	     R5: QAM_16;
	     R6: QAM_64;
	     R7: QAM_64;
          endcase;
endfunction


(* synthesize *)
module mkConvEncoderInstance(ConvEncoder#(TXGlobalCtrl,12,1,24,2));
   Vector#(2,Bit#(7)) gen_polys = newVector();
   gen_polys[0] = 7'b1011011;
   gen_polys[1] = 7'b1111001;
   ConvEncoder#(TXGlobalCtrl,12,1,24,2) conv_encoder;
   conv_encoder <- mkConvEncoder(gen_polys);
   return conv_encoder;
endmodule

(* synthesize *)
module mkPuncturerInstance (Puncturer#(TXGlobalCtrl,24,24,48,48));
   Bit#(6) f1_sz = 0;
   Bit#(4) f2_sz = 0;
   Bit#(2) f3_sz = 0;
   
   Puncturer#(TXGlobalCtrl,24,24,48,48) puncturer;
   puncturer <- mkPuncturer(puncturerMapCtrl,
			    parFunc(f1_sz,p1),
			    parFunc(f2_sz,p2),
			    parFunc(f3_sz,p3));
   return puncturer;
endmodule

(* synthesize *)
module mkDepuncturerInstance (Depuncturer#(TXGlobalCtrl,24,24,48,48));
   function DepunctData#(24) dpp1(DepunctData#(18) x);
      return parDepunctFunc(dp1,x);
   endfunction
   
   function DepunctData#(24) dpp2(DepunctData#(16) x);
      return parDepunctFunc(dp2,x);
   endfunction
   
   function DepunctData#(20) dpp3(DepunctData#(12) x);
      return parDepunctFunc(dp3,x);
   endfunction
   
   Depuncturer#(TXGlobalCtrl,24,24,48,48) depuncturer;
   depuncturer <- mkDepuncturer(puncturerMapCtrl,dpp1,dpp2,dpp3);
   return depuncturer;
endmodule

(* synthesize *)
module mkMapperInstance (Mapper#(TXGlobalCtrl,24,48,2,14));
   Mapper#(TXGlobalCtrl,24,48,2,14) mapper;
   mapper <- mkMapper(modulationMapCtrl,True);
   return mapper;
endmodule

(* synthesize *)
module mkDemapperInstance (Demapper#(TXGlobalCtrl,48,24,2,14,ViterbiMetric));
   Demapper#(TXGlobalCtrl,48,24,2,14,ViterbiMetric) demapper;
   demapper <- mkDemapper(modulationMapCtrl,True);
   return demapper;
endmodule

(*synthesize*) 
module mkFFTInstance (FFT#(TXGlobalCtrl,64,2,14));
  FFT#(TXGlobalCtrl,64,2,14) fft <- mkFFT;
  return fft;
endmodule

(*synthesize*) 
module mkIFFTInstance (IFFT#(TXGlobalCtrl,64,2,14));
  IFFT#(TXGlobalCtrl,64,2,14) ifft <- mkIFFT;
  return ifft;
endmodule


module mkConvolutionalDecoderTest#(Viterbi#(TXGlobalCtrl, 24, 12) convolutionalDecoder) (Empty);

   // state elements
   let conv_encoder <- mkConvEncoderInstance;
   let puncturer <- mkPuncturerInstance;
   let mapper <- mkMapperInstance;
   let demapper <- mkDemapperInstance;
   let depuncturer <- mkDepuncturerInstance;
   let firstCtrl =  TXGlobalCtrl{firstSymbol:False, rate:R0};
   let ifft <- mkIFFTInstance;
   let fft  <- mkFFTInstance;

   Reg#(TXGlobalCtrl) ctrl <- mkReg(TXGlobalCtrl{firstSymbol:False,
						 rate:R0});

   Reg#(Bit#(16)) counter <- mkReg(0);
   Reg#(Bit#(12)) in_data <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(Bit#(12)) out_data <- mkReg(0);
   Reg#(Bit#(64)) errors <- mkConfigReg(0); // accumulated errors
   Reg#(Bit#(64)) total <- mkConfigReg(0); // total bits received
   
   rule putNewRate(counter == 0);
      let new_ctrl = nextCtrl(ctrl);
      let new_data = in_data + 1;
      let mask = 12'h03F; // make sure the 6 MSBs are 0s
      let new_mesg = Mesg {control: new_ctrl,
                           data: new_data & mask};
      let new_counter = getNewCounter(new_ctrl);
      $display("Testbench sets counter to %d", getNewCounter(new_ctrl));
      ctrl <= new_ctrl;
      $display("ConvEncoder Input: %h", new_data & mask);
      in_data <= new_data;
      counter <= new_counter;
      conv_encoder.in.put(new_mesg);
      `ifdef isDebug
      $display("Conv Encoder In Mesg: rate:%d, data:%b, counter:%d",new_ctrl.rate,new_data&mask,new_counter);
      `endif
   endrule

   rule putNewData(counter > 0);
      let new_ctrl = ctrl;
      let new_data = in_data + 1;
      let mask = 12'h03F; // make sure the 6 MSBs are 0s
      let new_mesg = Mesg {control: new_ctrl,
                           data: new_data & mask};
      let new_counter = counter - 1;
      in_data <= new_data;
      counter <= new_counter;
      conv_encoder.in.put(new_mesg);
      $display("ConvEncoder Input: %h", new_data & mask);
      `ifdef isDebug
      $display("Conv Encoder In Mesg: rate:%d, data:%b, counter:%d",new_ctrl.rate,new_data&mask,new_counter);
      `endif
   endrule
   
   rule putPuncturer(True);
      let mesg <- conv_encoder.out.get;
      puncturer.in.put(mesg);
      `ifdef isDebug
      $display("Conv Encoder Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
      `endif
   endrule
   
   rule putMapper(True);
      let mesg <- puncturer.out.get;
      mapper.in.put(mesg);
      `ifdef isDebug
      $display("Puncturer Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
      `endif
   endrule
   
   rule putIFFT;
     let mesg <- mapper.out.get;
     ifft.in.put(Mesg{control:mesg.control,
                      data:append(mesg.data,replicate(0))});
   endrule

   rule modifyChannel;
    Mesg#(TXGlobalCtrl,
          Vector#(64,FPComplex#(2,14))) timeDomain <- ifft.out.get;
   
    // doesn't vector have length or something?
    for(Integer i = 0; i < 64; i = i+1) 
      begin
        let rawNoisyData = addNoise(pack(timeDomain.data[i].rel), 
                                    pack(timeDomain.data[i].img),
                                    0,0);
        timeDomain.data[i].img = unpack(truncateLSB(rawNoisyData));
        timeDomain.data[i].rel = unpack(truncate(rawNoisyData));
      end    

    fft.in.put(timeDomain);//(timeDomainPlusError);
   endrule 

   rule putDemapper(True);
      let freqDomain <- fft.out.get;
      demapper.in.put(Mesg{control:freqDomain.control,
                           data:take(freqDomain.data)});
      `ifdef isDebug
      $display("FFT Out Mesg: rate:%d, data:%h",freqDomain.control.rate,freqDomain.data);
      `endif
   endrule
   
   rule putDepuncturer(True);
      let mesg <- demapper.out.get;
      depuncturer.in.put(mesg);
      `ifdef isDebug
      $display("Demapper Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
      `endif
   endrule

   rule putViterbi(True);
      let mesg <- depuncturer.out.get;
      convolutionalDecoder.in.put(mesg); 
      `ifdef isDebug
      for(Integer i = 0; i < 24; i = i + 1)
         $display("ConvDecoder In %o",mesg.data[i]);
      $display("Depuncturer Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
      `endif
   endrule
   
   rule getOutput(True);
      let mesg <- convolutionalDecoder.out.get;
      let mask = 12'h03F;
      let expected_data = mask & (out_data + 1); 
      let diff = pack(mesg.data) ^ expected_data; // try to get the bits that are different
      let no_error_bits = countOnes(diff); // one = error bit
      errors <= errors + zeroExtend(pack(no_error_bits));
      total <= total + 12;
      out_data <= out_data + 1;
      for(Integer i = 0; i < 12; i = i + 1)
         begin
//            $display("Expected %b",expected_data[i]);
            $display("ConvolutionalDecoder Out %b expected %b error %b",mesg.data[i],expected_data[i],mesg.data[i]!=expected_data[i]);
         end
      `ifdef isDebug
      $display("Cycle: %d ConvolutionalDecoder Out Mesg: rate:%d, data:%b, no_error_bits: %d",cycle,mesg.control.rate,mesg.data,no_error_bits);
      `endif
   endrule
      
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == finishTime)
	 begin
            $display("ConvolutionalDecoder testbench finished at cycle %d",cycle);
            $display("Convolutional encoder BER was set as %d percent",getConvOutBER);
            $display("ConvolutionalDecoder performance total bit errors %d out of %d bits received",errors,total);
            $finish;
         end
      `ifdef isDebug
      $display("Cycle: %d",cycle);
      `endif
   endrule
   
endmodule
   
   




