import Connectable::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

import Controls::*;
import DataTypes::*;
import Interfaces::*;
import LibraryFunctions::*;
import Parameters::*;
import StreamFIFO::*;

typedef struct{
   Bit#(11)   length;  // data to send MAC PDU
   Rate       rate;    // data rate (determine by BS before)
   CPSizeCtrl cpSize;  // cp size in term of symbol size
   Bit#(4)    bsid;    // base station id it subscribe to
   Bit#(4)    uiuc;    // uplink profile
   Bit#(4)    fid;     // frame number 
   Bit#(3)    power;   // transmit power level (not affecting baseband)
} TXVector deriving (Eq, Bits);

typedef enum{ SendData, SendPadding }
        TXState deriving (Eq, Bits);

interface WiMAXTXController;
   method Action txStart(TXVector txVec);
   method Action txData(Bit#(8) inData);
   method Action txEnd();
   interface Get#(ScramblerMesg#(TXScramblerAndGlobalCtrl,
				 ScramblerDataSz)) out;
endinterface
      
// construct scramblerSeed
function Bit#(ScramblerShifterSz) makeSeed(TXVector txVec);
   return reverseBits({txVec.bsid,2'b11,txVec.uiuc,1'b1,txVec.fid});
endfunction   

// decr txVector length
function TXVector decrTXVectorLength(TXVector txVec);
   return TXVector{length: txVec.length - 1,
		   rate: txVec.rate,
		   cpSize: txVec.cpSize,
		   bsid: txVec.bsid,
		   uiuc: txVec.uiuc,
		   fid: txVec.fid,
		   power: txVec.power};
endfunction

// get maximum number of padding (basic unit is 8 bits) required for each rate
function Bit#(7) maxPadding(Rate rate);
   return case (rate)
	     R0: 11;
	     R1: 23;
	     R2: 35; 
	     R3: 47;
	     R4: 71;
	     R5: 95;
	     R6: 107;
	  endcase;
endfunction      

// construct scrambler mesg
function ScramblerMesg#(TXScramblerAndGlobalCtrl,ScramblerDataSz)
   makeMesg(Bit#(ScramblerDataSz) bypass,
	    Maybe#(Bit#(ScramblerShifterSz)) seed,
	    Bool firstSymbol,
	    Rate rate,
	    CPSizeCtrl cpSize,
	    Bit#(ScramblerDataSz) data);
   let sCtrl = TXScramblerCtrl{bypass: bypass,
			       seed: seed};
   let gCtrl = TXGlobalCtrl{firstSymbol: firstSymbol,
			    rate: rate,
			    cpSize: cpSize};
   let ctrl = TXScramblerAndGlobalCtrl{scramblerCtrl: sCtrl,
				       globalCtrl: gCtrl};
   let mesg = Mesg{control:ctrl, data:data};
   return mesg;
endfunction

(* synthesize *)
module mkWiMAXTXController(WiMAXTXController);
   
   //state elements
   Reg#(Bool)                 busy <- mkReg(False);
   Reg#(TXState)           txState <- mkRegU;
   Reg#(Bit#(7))             count <- mkRegU;
   Reg#(Bool)               fstSym <- mkRegU;
   Reg#(Bool)              rstSeed <- mkRegU;
   Reg#(TXVector)         txVector <- mkRegU;
   FIFO#(ScramblerMesg#(TXScramblerAndGlobalCtrl,ScramblerDataSz)) outQ;
   outQ <- mkSizedFIFO(2);
   
   // rules
   rule sendingPadding(busy && txState == SendPadding);
      if (count == 0) 
	 busy <= False;
      else
	 begin
	    let bypass = (count == 1) ? 8'hFF : 8'h00; // tail as unscramble 0
	    let seed = tagged Invalid;
	    let fstSym = False;
	    let rate = txVector.rate;
	    let cpSz = txVector.cpSize;
	    let data = (count == 1) ? 8'h00 : 8'hFF ;
	    let mesg = makeMesg(bypass,seed,fstSym,rate,cpSz,data);
	    outQ.enq(mesg);
	    count <= count - 1;
	    $display("sendingPadding"); 
	 end
   endrule
   
   // methods
   method Action txStart(TXVector txVec) if (!busy);
      txVector <= txVec;
      busy <= True;
      txState <= SendData;
      count <= 0;
      rstSeed <= True;
      fstSym <= True;
      $display("txStart");
   endmethod
   
   method Action txData(Bit#(8) inData) 
      if (busy && txState == SendData && txVector.length > 0);
      let bypass = 8'h00;
      let seedVal = makeSeed(txVector);
      let seed = rstSeed ? tagged Valid seedVal : tagged Invalid;
      let rate = txVector.rate;
      let cpSz = txVector.cpSize;
      let mesg = makeMesg(bypass,seed,fstSym,rate,cpSz,inData);
      let newTXVec = decrTXVectorLength(txVector);
      outQ.enq(mesg);
      rstSeed <= False;
      fstSym <= (count == 0) ? False : fstSym;
      txVector <= newTXVec;
      if (newTXVec.length == 0)
	 begin
	    txState <= SendPadding;
	    if (count == 0)
	       count <= maxPadding(txVector.rate) + 1; // need a tail
	 end
      else
	 count <= (count == 0) ? maxPadding(txVector.rate) : count - 1;
      $display("txData");
   endmethod
   
   method Action txEnd();
      busy <= False;
   endmethod
	    
   interface out = fifoToGet(outQ);   
endmodule   






