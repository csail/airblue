import Controls::*;
import DataTypes::*;
import FIFO::*;
import GetPut::*;
import Interfaces::*;
import LibraryFunctions::*;

module mkPilotInsert#(function PilotInsertCtrl 
			 mapCtrl(ctrl_t ctrl), 
		      function Symbol#(o_n,i_prec,f_prec) 
			 insertPilot(Symbol#(i_n,i_prec,f_prec) data,
				     Bit#(1) p),
		      Bit#(p_sz) prbsMask,
		      Bit#(p_sz) initSeq)
   (PilotInsert#(ctrl_t, i_n, o_n, i_prec, f_prec))
    provisos (Bits#(ctrl_t,ctrl_sz),
	      Add#(1,xxA,p_sz),
	      Add#(xxA,1,p_sz));
   			 
   // state elements
   Reg#(Bit#(p_sz)) pilot <- mkReg(initSeq);
//   FIFO#(PilotInsertMesg#(ctrl_t,i_n,i_prec,f_prec))  inQ;
   FIFO#(IFFTMesg#(ctrl_t,o_n,i_prec,f_prec)) outQ;
//   inQ <- mkLFIFO;
   outQ<- mkSizedFIFO(2);
   
//     // rules
//     rule compute(True);
//        let iMesg = inQ.first;
//        let iCtrl = iMesg.control;
//        let iData = iMesg.data;
//        let pCtrl = mapCtrl(iCtrl);
//        let iPilot = (pCtrl == PilotNorm) ? pilot : initSeq;
//        let feedback = genXORFeedback(prbsMask,iPilot);
//        Bit#(xxA) tPilot = tpl_2(split(iPilot));
//        let newPilot = {tPilot,feedback};
//        let oData = insertPilot(iData,feedback);
//        let oMesg = Mesg{ control:iCtrl, data: oData };
//        inQ.deq;
//        outQ.enq(oMesg);
//        pilot <= newPilot;
//      endrule
		
   // methods
   interface Put in;
      method Action put(PilotInsertMesg#(ctrl_t,i_n,i_prec,f_prec) iMesg);
	 let iCtrl = iMesg.control;
	 let iData = iMesg.data;
	 let pCtrl = mapCtrl(iCtrl);
	 let iPilot = (pCtrl == PilotNorm) ? pilot : initSeq;
	 let feedback = genXORFeedback(prbsMask,iPilot);
	 Bit#(xxA) tPilot = tpl_2(split(iPilot));
	 let newPilot = {tPilot,feedback};
	 let oData = insertPilot(iData,feedback);
	 let oMesg = Mesg{ control:iCtrl, data: oData };
	 outQ.enq(oMesg);
	 pilot <= newPilot;
      endmethod
   endinterface

   interface out = fifoToGet(outQ);
endmodule


