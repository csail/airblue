import Controls::*;
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

// testing wifi setting

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
   Rate newRate = case (ctrl.rate)
		     R0: R1;
		     R1: R2;
		     R2: R3;
		     R3: R4;
		     R4: R5;
		     R5: R6;
		     R6: R7;
		     R7: R0;
		  endcase; // case(rate)
   return TXGlobalCtrl{ firstSymbol: False, rate: newRate};
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
   DepunctData#(4) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[2] = x[2];
   return outVec;
endfunction // Bit
   
function DepunctData#(6) dp2 (DepunctData#(4) x);
   DepunctData#(6) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[2] = x[2];
   outVec[5] = x[3];
   return outVec;
endfunction // Bit

// not used in wifi   
function DepunctData#(10) dp3 (DepunctData#(6) x);
   DepunctData#(10) outVec = replicate(4);
   return outVec;
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

// (* synthesize *)
module mkConvEncoderInstance(ConvEncoder#(TXGlobalCtrl,12,24));
   ConvEncoder#(TXGlobalCtrl,12,24) convEncoder;
   convEncoder <- mkConvEncoder(7'b1011011,7'b1111001);
   return convEncoder;
endmodule

// (* synthesize *)
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

// (* synthesize *)
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

// (* synthesize *)
module mkMapperInstance (Mapper#(TXGlobalCtrl,24,48,2,14));
   Mapper#(TXGlobalCtrl,24,48,2,14) mapper;
   mapper <- mkMapper(modulationMapCtrl,True);
   return mapper;
endmodule

// (* synthesize *)
module mkDemapperInstance (Demapper#(TXGlobalCtrl,48,24,2,14,ViterbiMetric));
   Demapper#(TXGlobalCtrl,48,24,2,14,ViterbiMetric) demapper;
   demapper <- mkDemapper(modulationMapCtrl,True);
   return demapper;
endmodule

// (* synthesize *)
module mkViterbiInstance(Viterbi#(TXGlobalCtrl,24,12));
   Viterbi#(TXGlobalCtrl,24,12) viterbi;
   viterbi <- mkViterbi;
   return viterbi;
endmodule

// (* synthesize *)
module mkViterbiTest (Empty);

   // state elements
   let convEncoder <- mkConvEncoderInstance;
   let puncturer <- mkPuncturerInstance;
   let mapper <- mkMapperInstance;
   let demapper <- mkDemapperInstance;
   let depuncturer <- mkDepuncturerInstance;
   let viterbi <- mkViterbiInstance;
   Reg#(TXGlobalCtrl) ctrl <- mkReg(TXGlobalCtrl{firstSymbol:False,
						 rate:R0});
   Reg#(Bit#(16)) counter <- mkReg(0);
   Reg#(Bit#(12))  inData <- mkReg(0);
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
      convEncoder.in.put(newMesg);
      $display("Conv Encoder In Mesg: rate:%d, data:%b, counter:%d",newCtrl.rate,newData,newCounter);
   endrule

   rule putNewData(counter > 0);
      let newCtrl = ctrl;
      let newData = inData + 1;
      let newMesg = Mesg { control: newCtrl,
			  data: newData};
      let newCounter = counter - 1;
      inData <= newData;
      counter <= newCounter;
      convEncoder.in.put(newMesg);
      $display("Conv Encoder In Mesg: rate:%d, data:%b, counter:%d",newCtrl.rate,newData,newCounter);
   endrule
   
   rule putPuncturer(True);
      let mesg <- convEncoder.out.get;
      puncturer.in.put(mesg);
      $display("Conv Encoder Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
   endrule
   
   rule putMapper(True);
      let mesg <- puncturer.out.get;
      mapper.in.put(mesg);
      $display("Puncturer Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
   endrule
   
   rule putDemapper(True);
      let mesg <- mapper.out.get;
      demapper.in.put(mesg);
      $display("Mapper Out Mesg: rate:%d, data:%h",mesg.control.rate,mesg.data);
   endrule
   
   rule putDepuncturer(True);
      let mesg <- demapper.out.get;
      depuncturer.in.put(mesg);
      $display("Demapper Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
   endrule

   rule putViterbi(True);
      let mesg <- depuncturer.out.get;
      viterbi.in.put(mesg);
      $display("Depuncturer Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
   endrule
   
   rule getOutput(True);
      let mesg <- viterbi.out.get;
      $display("Viterbi Out Mesg: rate:%d, data:%b",mesg.control.rate,mesg.data);
   endrule
      
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 500000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
   
endmodule
   
   




