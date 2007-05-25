import FIFO::*;
import Vector::*;
import GetPut::*;

//import ReedTypes::*;
//import IReedSolomon::*;
//import mkReedSolomon::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;
import ofdm_parameters::*;
import ofdm_reed_types::*;
import ofdm_reed_common::*;
import ofdm_reed_decoder_core::*;

// import DataTypes::*;
// import Interfaces::*;
// import Controls::*;

Polynomial 	primitive_polynomial = 8'b00011101;

module mkReedDecoder#(function ReedSolomonCtrl#(8) mapCtrl(ctrl_t ctrl))
   (ReedDecoder#(ctrl_t,sz,sz))
    provisos(Mul#(num,8,sz),
             Bits#(ctrl_t, ctrl_sz),
	     Log#(num,num_sz));
			 
   // state elements
   FIFO#(ctrl_t)                         ctrlQ <- mkSizedFIFO(4);			 
   FIFO#(DecoderMesg#(ctrl_t,sz,Bit#(1)))  inQ <- mkLFIFO;
   FIFO#(DecoderMesg#(ctrl_t,sz,Bit#(1))) outQ <- mkSizedFIFO(2);
   IReedSolomon                             rs <- mkReedSolomon(primitive_polynomial);
   Reg#(Bit#(8))  inCounter <- mkReg(0);
   Reg#(Bit#(8)) outCounter <- mkReg(0);
   Reg#(Bit#(num_sz)) inCnt <- mkReg(0);
   Reg#(Bit#(num_sz)) outCnt <- mkReg(0);
   Reg#(Vector#(num,Byte)) inBuf  <- mkRegU;
   Reg#(Vector#(num,Byte)) outBuf <- mkRegU;
   
   // constants
   Bit#(num_sz) numSz = fromInteger(valueOf(num) - 1);
   Bit#(8)      num8b  = fromInteger(valueOf(num));
   			
   rule dropRSFlag(True);
      let flag <- rs.rs_flag.get;
      $display("rs decoder error:%d",flag);
   endrule
 
   rule getFromRS (True);
      let ctrl = ctrlQ.first;
      let rCtrl = mapCtrl(ctrl);
      let rsOutput <- rs.rs_output.get;
      let newOutCnt = (outCnt == numSz) ? 0 : outCnt + 1;
      let newOutBuf = update(outBuf,outCnt,rsOutput);
      let newOutCounter =  (outCounter == 0) ? rCtrl.in : outCounter;
      if (outCnt == numSz)
	 outQ.enq(DecoderMesg{ control: ctrl, data: unpack(pack(newOutBuf))});
      if (outCounter == num8b)
	 ctrlQ.deq;
      outCnt <= newOutCnt;
      outBuf <= newOutBuf;
      outCounter <= newOutCounter - num8b;
   endrule

   rule putToRS0 (inCnt == 0);
      let mesg = inQ.first();
      let rCtrl = mapCtrl(mesg.control);
      Vector#(num,Byte) newInBuf = unpack(pack(mesg.data));
      let rsInput = newInBuf[inCnt]; 
      let newInCnt = numSz - 1;
      let newInCounter  = (inCounter == 0) ? (rCtrl.in + rCtrl.out) : inCounter;
      inQ.deq();
      if (inCounter == 0)
	 begin
	    ctrlQ.enq(mesg.control);
	    rs.rs_t_in.put(rCtrl.out>>1);
	    rs.rs_k_in.put(rCtrl.in);
	 end
      rs.rs_input.put(rsInput);
      inBuf <= newInBuf;
      inCnt <= newInCnt;
      inCounter  <= newInCounter - num8b;
   endrule
   
   rule putToRS1 (inCnt != 0);
      let rsInput = inBuf[inCnt]; 
      let newInCnt = inCnt - 1;
      rs.rs_input.put(rsInput);
      inCnt  <= newInCnt;
   endrule

   interface in  = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule
