import DataTypes::*;
import Interfaces::*;
import Controls::*;
import FPComplex::*;
import Complex::*;
import FixedPoint::*;
import LibraryFunctions::*;
import Vector::*;
import FIFO::*;
import GetPut::*;

// mkMapper definition, 
// i_n must be multiple of 12
// o_n must equal no of data carriers, dividable by i_n
module mkMapper#(function Modulation mapCtrl(ctrl_t ctrl),
		 Bool negateInput)
    (Mapper#(ctrl_t,i_n,o_n,i_prec,f_prec))
    provisos(Bits#(ctrl_t, ctrl_sz),
             Add#(1,x,i_prec),
             Literal#(FixedPoint#(i_prec,f_prec)),
	     Mul#(qpsk_n,2,i_n),
	     Mul#(qam_16_n,4,i_n),
	     Mul#(qam_64_n,6,i_n),
	     Mul#(i_n,xxA,o_n),
	     Mul#(qpsk_n,xxB,o_n),
	     Mul#(qam_16_n,xxC,o_n),
	     Mul#(qam_64_n,xxD,o_n),
	     Log#(xxD,s_sz));

   // constants
   Bit#(s_sz) bpskSz = fromInteger(valueOf(xxA)-1);
   Bit#(s_sz) qpskSz = fromInteger(valueOf(xxB)-1);
   Bit#(s_sz) qam16Sz = fromInteger(valueOf(xxC)-1);
   Bit#(s_sz) qam64Sz = fromInteger(valueOf(xxD)-1);

   // state elements
   FIFO#(MapperMesg#(ctrl_t, i_n)) inQ <- mkLFIFO;
   FIFO#(PilotInsertMesg#(ctrl_t,o_n,i_prec,f_prec)) outQ;
   outQ <- mkSizedFIFO(2);
   Reg#(ctrl_t) lastCtrl <- mkRegU;
   Reg#(Bit#(s_sz)) counter <- mkReg(0);
   Reg#(Vector#(o_n,FPComplex#(i_prec,f_prec))) buffer <- mkRegU;
   
   // rules
   rule map(True);
      let mesg   = inQ.first();
      let data   = mesg.data;
      let ctrl = (counter == 0) ? mesg.control : lastCtrl;
      let format = mapCtrl(ctrl);
      let checkSz = case (format)
		       BPSK: bpskSz;
		       QPSK: qpskSz;
		       QAM_16: qam16Sz;
		       QAM_64: qam64Sz;
		    endcase;
      let newCounter = (counter == checkSz) ? 0 : counter + 1;
      Vector#(i_n,Bit#(1)) bpskDataVec = unpack(data);
      let bpskMapVec = map(mapBPSK(negateInput),bpskDataVec);
      Vector#(qpsk_n,Bit#(2)) qpskDataVec = unpack(data);
      let qpskMapVec = map(mapQPSK(negateInput),qpskDataVec);
      Vector#(qam_16_n,Bit#(4)) qam16DataVec = unpack(data);
      let qam16MapVec = map(mapQAM_16(negateInput),qam16DataVec);
      Vector#(qam_64_n,Bit#(6)) qam64DataVec = unpack(data);
      let qam64MapVec = map(mapQAM_64(negateInput),qam64DataVec);
      Vector#(o_n, FPComplex#(i_prec,f_prec)) finalVec = buffer;
      finalVec = case (format)
		    BPSK: sv_truncate(append(finalVec,bpskMapVec));
		    QPSK: sv_truncate(append(finalVec,qpskMapVec));
		    QAM_16: sv_truncate(append(finalVec,qam16MapVec));
		    QAM_64: sv_truncate(append(finalVec,qam64MapVec));
		 endcase;
      inQ.deq();
      lastCtrl <= ctrl;
      buffer <= finalVec;
      counter <= newCounter;
      if (counter == checkSz)
	 outQ.enq(Mesg{control: ctrl, data: finalVec});
   endrule
   
   // methods
   interface in  = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule






