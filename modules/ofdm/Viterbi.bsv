import FIFO::*;
import Vector::*;
import Monad::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_parameters::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

import VParams::*;
import IViterbi::*;

// import Interfaces::*;
// import Parameters::*;
// import DataTypes::*;

//`define isDebug True // uncomment this line to display error

module mkViterbi (Viterbi#(ctrl_t,n2,n))
   provisos(Add#(n,n,n2),
	    Add#(n2,1,n2p1),
	    Add#(n,1,np1),
	    Log#(n2p1,ln2),
	    Log#(np1,ln),
	    Bits#(ctrl_t, ctrl_sz));
   
   // constants
   Bit#(ln)  checkN  = fromInteger(valueOf(n));
   Bit#(ln2) checkN2 = fromInteger(valueOf(n2));
   Integer  tbLength = valueOf(TBLength);
   Integer  tbStages = valueOf(NoOfTBStage);
   Integer   ctrlQSz = ((tbLength + tbStages)/valueOf(n)) + 1; 
   
   // state elements
//   Reg#(ctrl_t) ctrl <- mkRegU;
   IViterbi viterbi <- mkIViterbiTB;     // murali TB
//   IViterbi viterbi <- mkIViterbiTBPath;   // alfred TB
   Reg#(Vector#(n2,ViterbiMetric)) inData <- mkReg(newVector);
   Reg#(Bit#(ln2)) inDataCount <- mkReg(checkN2);
   Reg#(Vector#(n,Bit#(1))) outData <- mkReg(newVector);
   Reg#(Bit#(ln)) outDataCount <- mkReg(0);
   FIFO#(ctrl_t) ctrlQ <- mkSizedFIFO(ctrlQSz);

  rule pushDataToViterbi (inDataCount != checkN2);
     VInType vData = newVector;
     Vector#(ConvOutSz, VMetric) tempV = newVector;
     for (Integer i = 0; i < fwd_steps; i = i + 1)
	begin
	   for (Integer j = 0; j < conv_out_sz; j = j + 1)
	      begin
		 let offset = i * conv_out_sz + j;
 		 tempV[j] = inData[inDataCount + fromInteger(offset)];
	      end
	   vData[i] = tempV;
	end
     viterbi.putData(vData);
     inDataCount <= inDataCount + fromInteger(fwd_steps * conv_out_sz);
     `ifdef isDebug
        $display("pushDataToViterbi");
     `endif 
  endrule

  rule pullDataFromViterbi (outDataCount != checkN);
     VOutType vData <- viterbi.getResult ();
     Vector#(n,Bit#(1)) newOutData = outData;
     for (Integer n = 0 ; n < fwd_steps; n = n + 1)
	begin
	   newOutData[outDataCount+fromInteger(n)] = vData[n];
	end
     outData <= newOutData;
     outDataCount <= outDataCount + fromInteger(fwd_steps);
     `ifdef isDebug
        $display("pullDataFromViterbi");
     `endif
  endrule

  interface Put in;
      method Action put(DecoderMesg#(ctrl_t,n2,ViterbiMetric) dataIn) 
	 if(inDataCount == checkN2);
         inData <= dataIn.data;
         inDataCount <= 0;
         ctrlQ.enq(dataIn.control);
	 `ifdef
	    $display("viterbi in");
	 `endif
      endmethod
  endinterface

  interface Get out;
      method ActionValue#(DecoderMesg#(ctrl_t,n,Bit#(1))) get() 
	 if(outDataCount == checkN);
	 ctrlQ.deq;
         outDataCount <= 0;	
	 `ifdef isDebug
	    $display("viterbi out");
	 `endif
         return Mesg{control: ctrlQ.first, data:outData};
      endmethod
  endinterface

endmodule
