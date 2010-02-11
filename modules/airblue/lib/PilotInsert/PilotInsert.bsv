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


