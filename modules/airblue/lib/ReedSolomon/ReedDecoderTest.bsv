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
import DataTypes::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import ReedEncoder::*;
import ReedDecoder::*;

// Global Parameters:
typedef enum {
   R0,  // BPSK 1/2
   R1,  // QPSK 1/2
   R2,  // QPSK 3/4
   R3,  // 16-QAM 1/2
   R4,  // 16-QAM 3/4
   R5,  // 64-QAM 2/3
   R6   // 64-QAM 3/4
} Rate deriving(Eq, Bits);

// may be an extra field for DL: sendPremable
typedef struct {
   Bool       firstSymbol; 
   Rate       rate;
   CPSizeCtrl cpSize;
} TXGlobalCtrl deriving(Eq, Bits);

function TXGlobalCtrl nextCtrl(TXGlobalCtrl ctrl);
   Rate newRate = case (ctrl.rate)
		     R0: R1;
		     R1: R2;
		     R2: R3;
		     R3: R4;
		     R4: R5;
		     R5: R6;
		     R6: R0;
		  endcase; // case(rate)
   return TXGlobalCtrl{ firstSymbol: False, rate: newRate, cpSize: CP0};
endfunction

function Bit#(16) getNewCounter(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: 11;
	     R1: 23;
	     R2: 35;
	     R3: 47;
	     R4: 71;
	     R5: 95;
	     R6: 107;
	  endcase;
endfunction

function ReedSolomonCtrl#(8) reedEncoderMapCtrl(TXGlobalCtrl ctrl);
    return case (ctrl.rate) matches
               R0   : ReedSolomonCtrl{in:12, out:0};
               R1   : ReedSolomonCtrl{in:24, out:8};
               R2   : ReedSolomonCtrl{in:36, out:4};
               R3   : ReedSolomonCtrl{in:48, out:16};
               R4   : ReedSolomonCtrl{in:72, out:8};
               R5   : ReedSolomonCtrl{in:96, out:12};
               R6   : ReedSolomonCtrl{in:108, out:12};
           endcase;
endfunction

(* synthesize *)
module mkReedEncoderInstance(ReedEncoder#(TXGlobalCtrl,8,8));
   ReedEncoder#(TXGlobalCtrl,8,8) reedEncoder;
   reedEncoder <- mkReedEncoder(reedEncoderMapCtrl);
   return reedEncoder;
endmodule

(* synthesize *)
module mkReedDecoderInstance(ReedDecoder#(TXGlobalCtrl,8,8));
   ReedDecoder#(TXGlobalCtrl,8,8) reedDecoder;
   reedDecoder <- mkReedDecoder(reedEncoderMapCtrl);
   return reedDecoder;
endmodule

(* synthesize *)
module mkReedDecoderTest (Empty);
   
   let reedEncoder <- mkReedEncoderInstance;
   let reedDecoder <- mkReedDecoderInstance;
   Reg#(TXGlobalCtrl) ctrl <- mkReg(TXGlobalCtrl{firstSymbol:False,
						 rate:R0,
                                                 cpSize:CP0});
   Reg#(Bit#(16)) counter <- mkReg(0);
   Reg#(Bit#(8))  inData <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putNewRate(counter == 0);
      let newCtrl = nextCtrl(ctrl);
      let newData = inData + 1;
      let newMesg = Mesg {control: newCtrl,
			  data: newData};
      let newCounter = getNewCounter(newCtrl);
      ctrl <= newCtrl;
      inData <= newData;
      counter <= newCounter;
      reedEncoder.in.put(newMesg);
      $display("Reed Encoder In Mesg: rate:%d, data:%b, counter:%d",newCtrl.rate,newData,newCounter);
   endrule

   rule putNewData(counter > 0);
      let newCtrl = ctrl;
      let newData = inData + 1;
      let newMesg = Mesg { control: newCtrl,
			  data: newData};
      let newCounter = counter - 1;
      inData <= newData;
      counter <= newCounter;
      reedEncoder.in.put(newMesg);
      $display("Reed Encoder In Mesg: rate:%d, data:%b, counter:%d",newCtrl.rate,newData,newCounter);
   endrule
   
   rule putConvEncoder(True);
      let mesg <- reedEncoder.out.get;
      DecoderMesg#(TXGlobalCtrl,8,Bit#(1)) newMesg = unpack(pack(mesg));
      reedDecoder.in.put(newMesg);
      $display("Reed Encoder Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
   endrule
      
   rule getOutput(True);
      let mesg <- reedDecoder.out.get;
      $display("Reed Decoder Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 500000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
   
endmodule
   
   




