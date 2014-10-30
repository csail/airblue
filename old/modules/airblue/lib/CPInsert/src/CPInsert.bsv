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

import FIFO::*;
import GetPut::*;
import Vector::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;

typedef enum{
   ProcNew,    // process new symbol
   ShortCP,    // sending short preamble CP
   ShortData,  // sending short preamble data
   LongCP,     // sending long preamble CP
   LongData,   // sending long preamble data
   SymbolCP,   // sending symbol CP
   SymbolData  // sending symbol data   
} CPState deriving (Bits, Eq);

module mkCPInsert#(function CPInsertCtrl mapCtrl (ctrl_t ctrl),
		   Symbol#(pn, i_prec, f_prec) sPreamble,
		   Symbol#(pn, i_prec, f_prec) lPreamble)
   (CPInsert#(ctrl_t,n,i_prec,f_prec))
   provisos (Bits#(ctrl_t,ctrl_sz),
	     Log#(n,n_idx),
	     Log#(pn,pn_idx));
   
   // constants
   Integer nInt = valueOf(n);
   Integer pnInt = valueOf(pn);
   Bit#(n_idx) maxN = fromInteger(nInt - 1);
   Bit#(pn_idx) maxPN = fromInteger(pnInt - 1); 
   Bit#(n_idx) nCP0Start = fromInteger(nInt - nInt/4);
   Bit#(n_idx) nCP1Start = fromInteger(nInt - nInt/8);
   Bit#(n_idx) nCP2Start = fromInteger(nInt - nInt/16);
   Bit#(n_idx) nCP3Start = fromInteger(nInt - nInt/32);
   Bit#(pn_idx) pnCP0Start = fromInteger(pnInt - pnInt/4);
   Bit#(pn_idx) pnCP1Start = fromInteger(pnInt - pnInt/8);
   Bit#(pn_idx) pnCP2Start = fromInteger(pnInt - pnInt/16);
   Bit#(pn_idx) pnCP3Start = fromInteger(pnInt - pnInt/32);
		      
   // state elements
   FIFO#(CPInsertMesg#(ctrl_t,n,i_prec,f_prec)) inQ <- mkLFIFO;
   FIFO#(DACMesg#(i_prec,f_prec)) outQ <- mkSizedFIFO(2);
   Reg#(CPState)      state <- mkReg(ProcNew);
   Reg#(Bit#(n_idx))   nCnt <- mkReg(0);
   Reg#(Bit#(pn_idx)) pnCnt <- mkReg(0);
		      
   // wires
   let inMesg = inQ.first;
   let inCtrl = inMesg.control;
   let inData = inMesg.data;
   let inCPCtrl = mapCtrl(inCtrl);
   let sendPre  = tpl_1(inCPCtrl);
   let cpSize   = tpl_2(inCPCtrl);
   let pnCPStart = case (cpSize)
		      CP0: pnCP0Start; 
		      CP1: pnCP1Start;
		      CP2: pnCP2Start;
		      CP3: pnCP3Start;
		   endcase;

   // rules
   rule procNew(state == ProcNew);
      let nCPStart = case (cpSize)
			CP0: nCP0Start; 
			CP1: nCP1Start;
			CP2: nCP2Start;
			CP3: nCP3Start;
		     endcase;
      if (sendPre == SendLong || sendPre == SendBoth) 
	 begin
	    outQ.enq((sendPre == SendLong) ? 
		     lPreamble[pnCPStart] :
		     sPreamble[pnCPStart]);
	    state <= (sendPre == SendLong) ? LongCP : ShortCP;
	    pnCnt <= pnCPStart + 1;
	    nCnt <= nCPStart;
	 end
      else
	 begin
	    outQ.enq(inData[nCPStart]);
	    state <= SymbolCP;
	    nCnt <= nCPStart + 1; 
	 end
   endrule			

   rule procPreamble(state == ShortCP || state == ShortData ||
		     state == LongCP || state == LongData);
      if (pnCnt == maxPN)
	 begin
	    state <= case (state)
			ShortCP: ShortData;
			ShortData: LongCP;
			LongCP: LongData;
			LongData: SymbolCP;
		     endcase;
	    pnCnt <= (state == ShortData) ? pnCPStart : 0;
	 end
      else
	 pnCnt <= pnCnt + 1;
      if (state == ShortCP || state == ShortData)
	 outQ.enq(sPreamble[pnCnt]);
      else
	 outQ.enq(lPreamble[pnCnt]);
   endrule		     

   rule procSymbol(state == SymbolCP || state == SymbolData);
      if (nCnt == maxN)
	 begin
	    nCnt <= 0;
	    if (state == SymbolData)
	       begin
		  state <= ProcNew;
		  inQ.deq;
	       end
	    else
	       state <= SymbolData;
	 end
      else
	 nCnt <= nCnt + 1;
      outQ.enq(inData[nCnt]);
   endrule		     
		      
   interface in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
   
endmodule   







