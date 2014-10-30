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

import ConfigReg::*;
import Connectable::*;
import CBus::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ModuleCollect::*;
import Vector::*;

// Local includes
import AirblueTypes::*;
import AirblueCommon::*;
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"


typedef enum{ Idle = 0, SendHeader = 1, AddPreData = 2, SendData = 3, SendPostData = 4, SendPadding = 5, SendTrailer = 6}
        TXState deriving (Eq, Bits);

interface TXController;
   method Action txStart(TXVector txVec);
   method Action txData(Bit#(8) inData);
   method Action txEnd();
   interface Get#(ScramblerMesg#(TXScramblerAndGlobalCtrl,
				 ScramblerDataSz)) out;
endinterface
      
// get maximum number of padding (basic unit is bit) required for each rate
function Bit#(8) maxPadding(Rate rate);
   Bit#(8) scramblerDataSz = fromInteger(valueOf(ScramblerDataSz)); // must be a factor of 12
   return fromInteger(bitsPerSymbol(rate)) - scramblerDataSz; 
endfunction      

function ScramblerMesg#(TXScramblerAndGlobalCtrl,ScramblerDataSz)
   makeMesg(Bit#(ScramblerDataSz) bypass,
	    Maybe#(Bit#(ScramblerShifterSz)) seed,
	    Bool firstSymbol,
	    Rate rate,
	    Bit#(ScramblerDataSz) data);
   let sCtrl = TXScramblerCtrl{bypass: bypass,
			       seed: seed};
   let gCtrl = TXGlobalCtrl{firstSymbol: firstSymbol,
			    rate: rate};
   let ctrl = TXScramblerAndGlobalCtrl{scramblerCtrl: sCtrl,
				       globalCtrl: gCtrl};
   let mesg = Mesg{control:ctrl, data:data};
   return mesg;
endfunction

// (* synthesize *)
module [CONNECTED_MODULE] mkTXController(TXController);
   
   //state elements
   Reg#(TXState)           txState <- mkReg(Idle);
   Reg#(Bit#(5))          sfifoRem <- mkReg(?);
   Reg#(Bit#(8))             count <- mkReg(?);
   Reg#(Bool)              rstSeed <- mkReg(?);
   Reg#(Bool)        postDataAdded <- mkReg(?);
   Reg#(Bool)            zeroAdded <- mkReg(?);
   Reg#(TXVector)         txVector <- mkReg(?);
   Reg#(PhyPacketLength)  txLength <- mkReg(?);
   StreamFIFO#(HeaderSz,TLog#(HeaderSz),Bit#(1)) sfifo <- mkStreamLFIFO; // size >= 16
   FIFOF#(ScramblerMesg#(TXScramblerAndGlobalCtrl,ScramblerDataSz)) outQ;
   outQ <- mkSizedFIFOF(2);
   
   // constants
   let sfifo_usage = sfifo.usage;
   let sfifo_free  = sfifo.free;
   Bit#(TLog#(HeaderSz)) scramblerDataSz = fromInteger(valueOf(ScramblerDataSz));
   
//    rule copyTxState(True);
// //      peepTxState <= peepTxState + 1;
//       peepTxState <= zeroExtend(pack(txState));
//    endrule
   
   // rules
   // send header (or trailer) non-scrambled and at basic rate
   rule sendHeader((txState == SendHeader || txState == SendTrailer)
                   && sfifo.usage >= scramblerDataSz);
      Bit#(ScramblerDataSz) bypass = maxBound; // header is unscrambled 
      let seed = tagged Invalid;
      let fstSym = sfifo.usage==fromInteger(valueOf(HeaderSz)); // only at the start of the first symbol
      let rate = R0;
      Bit#(ScramblerDataSz) data = pack(take(sfifo.first));
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      sfifo.deq(scramblerDataSz);
      if (sfifo.usage == scramblerDataSz) // end of header
	 begin
            if (txState == SendHeader)
               begin
	          txState <= AddPreData;
               end
            else
               begin
                  txState <= Idle;
               end
	 end
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires sendHeader isTrailer? %d",txState == SendTrailer);
         end
   endrule
   
   // send predata (date come before actual payload) at payload rate 
   rule addPreData(txState == AddPreData);
      if (isValid(txVector.pre_data))
         begin
            sfifo.enq(fromInteger(valueOf(PreDataSz)),append(unpack(fromMaybe(?,txVector.pre_data)),replicate(0)));
         end
      txState <= SendData;
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires addPreData");
         end
   endrule
   
   rule sendData(txState == SendData 
		 && sfifo_usage >= scramblerDataSz);
      Bit#(ScramblerDataSz) bypass = 0;
      let seed = rstSeed ? 
                 tagged Valid magicConstantSeed : 
                 tagged Invalid;
      let fstSym = False;
      let rate = txVector.header.rate;
      Bit#(ScramblerDataSz) data = pack(take(sfifo.first));
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      sfifo.deq(scramblerDataSz);
      count <= (count == 0) ? 
               maxPadding(txVector.header.rate) : 
               count - zeroExtend(scramblerDataSz);
      rstSeed <= False;
      if (zeroAdded) // switch to padding
         begin
            txState <= SendPadding;
         end
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires sendData count =  %d", count);
         end
   endrule
     
   rule addTail(txState == SendData
		&& sfifo_usage < scramblerDataSz 
		&& txLength == 0 
                && !postDataAdded);
      if (isValid(txVector.post_data))
         begin
            sfifo.enq(fromInteger(valueOf(PostDataSz)),append(unpack(fromMaybe(?,txVector.post_data)),replicate(0)));
         end
      postDataAdded <= True;
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires addTail");
         end
   endrule
   
   rule addZero(txState == SendData
		&& sfifo_usage < scramblerDataSz
                && txLength == 0
		&& postDataAdded 
                && !zeroAdded); 
      let enqSz = scramblerDataSz - sfifo_usage;
      if (sfifo_usage > 0) // only add zero when usage > 0
	 sfifo.enq(enqSz,replicate(0));
      zeroAdded <= True;
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires addZero");
         end
   endrule   
   
//    rule sendLast( txState == SendData &&
// 		 !addZero);
//       Bit#(ScramblerDataSz) bypass = 0;
//       let seed = tagged Invalid;
//       let fstSym = False;
//       let rate = txVector.rate;
//       Bit#(ScramblerDataSz) data = truncate(pack(sfifo.first));
//       let mesg = makeMesg(bypass,seed,fstSym,rate,data);
//       if (sfifo_usage > 0) // only send if usage > 0
// 	 begin
// 	    outQ.enq(mesg);
// 	    sfifo.deq(sfifo_usage);
// 	    count <= (count == 0) ? 
//                      maxPadding(txVector.rate) : 
// 		     count - zeroExtend(scramblerDataSz);
// 	 end
//       txState <= SendPadding;
//       $display("%m TXCtrl fires sendLast");
//    endrule
   
   rule sendPadding(txState == SendPadding 
                    && count > 0);
      Bit#(ScramblerDataSz) bypass = 0;
      let seed = tagged Invalid;
      let fstSym = False;
      let rate = txVector.header.rate;
      Bit#(ScramblerDataSz) data = 0;
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      count <= count - zeroExtend(scramblerDataSz);
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires sendPadding");      
         end
   endrule
   
   rule becomeIdleOrAddTrailer(txState == SendPadding 
                               && count == 0);
      if (txVector.header.has_trailer)
         begin
            txState <= SendTrailer;
            sfifo.enq(fromInteger(valueOf(HeaderSz)),append(unpack(encoderHeader(txVector.header,True)),replicate(0)));
         end
      else
         begin
            txState <= Idle;
         end
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires becomeIdle");
         end
   endrule

//    rule checkOutQ(True);
//       $display("%m TXCtrl outQ notFull:%d notEmpty:%d",outQ.notFull,outQ.notEmpty);
//    endrule
   
   // methods
   method Action txStart(TXVector txVec) if (txState == Idle);
      txVector <= txVec;
      txLength <= txVec.header.length;
      txState <= SendHeader;
      rstSeed <= True;
      postDataAdded <= False;
      zeroAdded <= False;
      count <= 0;
      sfifo.enq(fromInteger(valueOf(HeaderSz)),append(unpack(encoderHeader(txVec.header,False)),replicate(0)));
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires txStart: %d", count);
         end
   endmethod
   
   method Action txData(Bit#(8) inData) 
      if (txState == SendData && sfifo_free >= 8 &&
	  txLength > 0);
      sfifo.enq(8,append(unpack(inData),replicate(0)));
      txLength <= txLength - 1;
      if(`DEBUG_TXCTRL == 1)
         begin
            $display("%m TXCtrl fires txData");
         end
   endmethod
   
   method Action txEnd();
      txState <= Idle;
      sfifo.clear;
   endmethod
	    
   interface Get out;
      method ActionValue#(ScramblerMesg#(TXScramblerAndGlobalCtrl,
	                                 ScramblerDataSz)) get();
         outQ.deq();
         return outQ.first;
      endmethod
   endinterface
endmodule 




