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
import Interfaces::*;
import LibraryFunctions::*;
import GetPut::*;
import Scrambler::*;

module mkDescrambler#(function ScramblerCtrl#(n,shifter_sz) 
			 mapCtrl(ctrl_t ctrl),
		      Bit#(shifter_sz) genPoly)
   (Descrambler#(ctrl_t,n,n))
   provisos(Add#(1,xxA,shifter_sz),
	    Bits#(ctrl_t,ctrl_sz));
   
   // id function
   function ctrl_t 
      descramblerConvertCtrl(ctrl_t ctrl);
      return ctrl;
   endfunction
			 
   let descrambler <- mkScrambler(mapCtrl,
				  descramblerConvertCtrl,
				  genPoly);
   return descrambler;
endmodule

// // auxiliary function
// function Tuple2#(Bit#(n), Bit#(sRegSz)) scramble(Bit#(n) inBit, Bit#(sRegSz) sReg, Bit#(sRegSz) mask)
//   provisos (Add#(1,xxA,sRegSz));

//       Integer sRegSzInt = valueOf(sRegSz);
//       Nat sRegSzNat = fromInteger(sRegSzInt);
//       Bit#(n) res = 0;
//       Bit#(sRegSz) newSReg = sReg;

//       for(Integer i = 0; i < valueOf(n); i = i + 1)
// 	begin
// 	   Bit#(1) temp = 0;
// 	   for(Integer j = 0; j < sRegSzInt; j = j + 1)
// 	     if (mask[j] == 1)
// 	       temp = temp ^ newSReg[j];
// 	   res[i] = inBit[i] ^ temp;
// 	   newSReg = {newSReg[sRegSzNat-1:1],temp};
// 	end

//       return tuple2(res, newSReg);

// endfunction

// // main function
// module mkDescrambler#(function DescramblerCtrl genCtrl(ctrl_t ctrl),
// 		      Bit#(sRegSz) mask,
// 		      Bit#(sRegSz) initSeq)
//   (Descrambler#(ctrl_t, n))
//   provisos (Add#(1, xxA, sRegSz),
// 	    Add#(1, xxB, n), Add#(sRegSz, xxC, n),
// 	    Bits#(DescramblerMesg#(ctrl_t,n), xxD));

//    Reg#(Bit#(sRegSz)) sReg <- mkReg(initSeq);
//    FIFO#(DescramblerMesg#(ctrl_t,n)) outQ <- mkSizedFIFO(2);
   
//     interface Put in;
//         method Action put(DescramblerMesg#(ctrl_t, n) inMsg);
//       let ctrl = genCtrl(inMsg.control); 
//       case (ctrl)
// 	Bypass: outQ.enq(inMsg);
// 	FixRst: 
// 	  begin
// 	     let res = scramble(inMsg.data, initSeq, mask);
// 	     outQ.enq(DescramblerMesg{ control: inMsg.control,
// 				       data: tpl_1(res)});
// 	     sReg <= tpl_2(res);
// 	  end
// 	DynRst:
// 	  begin
// 	     Tuple2#(Bit#(xxC),Bit#(sRegSz)) splittedData = split(inMsg.data);
// 	     let newInitSeq = reverseBits(tpl_2(splittedData));
// 	     let newInData = tpl_1(splittedData);
// 	     let res = scramble(newInData, newInitSeq, mask);
// 	     Bit#(n) outData = {tpl_1(res), newInitSeq};
// 	     outQ.enq(DescramblerMesg{ control: inMsg.control,
// 				       data: outData});
// 	     sReg <= tpl_2(res);
// 	  end
// 	Norm:
// 	  begin
// 	     let res = scramble(inMsg.data, sReg, mask);
// 	     outQ.enq(DescramblerMesg{ control: inMsg.control,
// 				       data:tpl_1(res)});
// 	     sReg <= tpl_2(res);
// 	  end
//       endcase // case(inMsg.ctrl)
//         endmethod
//     endinterface

//     interface out = fifoToGet(outQ);
// endmodule // mkDescrambler         

