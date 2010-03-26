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

// import CBusUtils::*;

// import Controls::*;
// import DataTypes::*;
// import FPGAParameters::*;
// import Interfaces::*;
// import LibraryFunctions::*;
// import MACPhyParameters::*;
// import ProtocolParameters::*;
// import StreamFIFO::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/c_bus_utils.bsh"


// typedef 16 PreDataSz;

// typedef 6  PostDataSz;

// typedef 24 HeaderSz;

// typedef Bit#(8) MACAddr; // mac address

// typedef Bit#(8) UID; // unique msg ID (for the same src, dest pair)

// typedef Maybe#(Bit#(PreDataSz))  PreData;

// typedef Maybe#(Bit#(PostDataSz)) PostData;

// typedef Bit#(HeaderSz) Header;

// typedef struct{
//    PhyPacketLength length;
//    Rate            rate; 
//    Bit#(3)         power;
//    Bool            has_trailer; // add trailer (postample + repeated header)
//    MACAddr         src_addr;
//    MACAddr         dst_addr;
//    UID             uid;
// } HeaderInfo deriving (Eq, Bits);

// typedef struct{
//    HeaderInfo header;    // information that should get to header/trailer (non-scrambled and sent at basic rate)
//    PreData    pre_data;  // information that sent before data (sent at the same rate as data), if invalid don't send anything
//    PostData   post_data; // information that sent after data (sent at the same rate as data), if invalid, don't send anything
// } TXVector deriving (Eq, Bits);


// typedef struct{
//    PhyPacketLength length;  // data to send in bytes
//    Rate            rate;    // data rate
//    Bit#(16)        service; // service bits, should be all 0s
//    Bit#(3)         power;   // transmit power level (not affecting baseband)
   
// } TXVector deriving (Eq, Bits);

typedef enum{ Idle = 0, SendHeader = 1, AddPreData = 2, SendData = 3, SendPostData = 4, SendPadding = 5, SendTrailer = 6}
        TXState deriving (Eq, Bits);

interface TXController;
   method Action txStart(TXVector txVec);
   method Action txData(Bit#(8) inData);
   method Action txEnd();
   interface Get#(ScramblerMesg#(TXScramblerAndGlobalCtrl,
				 ScramblerDataSz)) out;
endinterface
      
// function Header encoderHeader(HeaderInfo header, Bool is_trailer);
//       Bit#(4) translate_rate = case (header.rate)   //somehow checking rate directly doesn't work
// 				  R0: 4'b1011;
// 				  R1: 4'b1111;
// 				  R2: 4'b1010; 
// 				  R3: 4'b1110;
// 				  R4: 4'b1001;
// 				  R5: 4'b1101;
// 				  R6: 4'b1000;
// 				  R7: 4'b1100;
// 			       endcase; // case(r)    
//       Bit#(1)  parity = getParity({translate_rate,pack(is_trailer),header.length});
//       Bit#(24) data = {6'b0,parity,header.length,pack(is_trailer),translate_rate};
//       return data;   
// endfunction

// get maximum number of padding (basic unit is bit) required for each rate
function Bit#(8) maxPadding(Rate rate);
   Bit#(8) scramblerDataSz = fromInteger(valueOf(ScramblerDataSz)); // must be a factor of 12
   return fromInteger(bitsPerSymbol(rate)) - scramblerDataSz; 
//    case (rate)
// 	     R0: 24 - scramblerDataSz;
// 	     R1: 36 - scramblerDataSz;
// 	     R2: 48 - scramblerDataSz; 
// 	     R3: 72 - scramblerDataSz;
// 	     R4: 96 - scramblerDataSz;
// 	     R5: 144 - scramblerDataSz;
// 	     R6: 192 - scramblerDataSz;
// 	     R7: 216 - scramblerDataSz;
// 	  endcase;
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
// module mkTXController(TXController);
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkTXController(TXController);
   
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) txStateOffset = fromInteger(valueOf(TxCtrlStateOffset));
   
   //state elements
   Reg#(TXState)           txState <- mkReg(Idle);
//   ConfigReg#(Bit#(AvalonDataWidth)) peepTxState <- mkCBRegR(txStateOffset,0);
   Reg#(Bit#(5))          sfifoRem <- mkRegU;
   Reg#(Bit#(8))             count <- mkRegU;
   Reg#(Bool)              rstSeed <- mkRegU;
   Reg#(Bool)        postDataAdded <- mkRegU;
   Reg#(Bool)            zeroAdded <- mkRegU;
   Reg#(TXVector)         txVector <- mkRegU;
   Reg#(PhyPacketLength)  txLength <- mkRegU;
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




