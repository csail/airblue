import FIFO::*;
import GetPut::*;
import Vector::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import DataTpyes::*;
// import Interfaces::*;

module mkConvEncoder#(Bit#(h_n) g1, Bit#(h_n) g2)
   (ConvEncoder#(ctrl_t,i_n,o_n))
   provisos (Add#(1,xxA,i_n),
	     Add#(1,h_n_m_1,h_n),
	     Mul#(i_n,2,o_n),
	     Bits#(ctrl_t,ctrl_sz));
   
   // state elements
   FIFO#(EncoderMesg#(ctrl_t,i_n)) inQ <- mkLFIFO;
   FIFO#(EncoderMesg#(ctrl_t,o_n)) outQ <- mkLFIFO;
   Reg#(Bit#(h_n)) histVal <- mkReg(0);
   
   // rules
   rule compute(True);
      let mesg = inQ.first;
      Vector#(i_n,Bit#(1)) inData = unpack(mesg.data);
      Vector#(h_n,Bit#(1)) fst = unpack(histVal);
      let histVec = map(pack,sscanl(shiftInAtN,fst,inData));
      let outVec1 = map(genXORFeedback(g1),histVec);
      let outVec2 = map(genXORFeedback(g2),histVec);
      let outData = pack(zip(outVec2,outVec1));
      inQ.deq;
      histVal <= last(histVec);
      outQ.enq(Mesg{ control: mesg.control,
		     data: outData});
   endrule
   
   //methods
   interface in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule




