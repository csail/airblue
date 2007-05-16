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
   Bit#(12) length;  // data to send in bytes
   Rate     rate;    // data rate 
   Bit#(16) service; // service bits, should be all 0s
   Bit#(3)  power;   // transmit power level (not affecting baseband)
} TXVector deriving (Eq, Bits);

typedef enum{ SendHeader, SendData, SendPadding }
        TXState deriving (Eq, Bits);

interface WiFiTXController;
   method Action txStart(TXVector txVec);
   method Action txData(Bit#(8) inData);
   method Action txEnd();
   interface Get#(ScramblerMesg#(TXScramblerAndGlobalCtrl,
				 ScramblerDataSz)) out;
endinterface
      
function Vector#(2,Bit#(12)) makeHeader(TXVector txVec);
      Bit#(4) translate_rate = case (txVec.rate)   //somehow checking rate directly doesn't work
				  R0: 4'b1011;
				  R1: 4'b1111;
				  R2: 4'b1010; 
				  R3: 4'b1110;
				  R4: 4'b1001;
				  R5: 4'b1101;
				  R6: 4'b1000;
				  R7: 4'b1100;
			       endcase; // case(r)    
      Bit#(1)  parity = getParity({translate_rate,txVec.length});
      Bit#(24) data = {6'b0,parity,txVec.length,1'b0,translate_rate};
      return(unpack(data));   
endfunction

// get maximum number of padding (basic unit is 12 bits) required for each rate
function Bit#(5) maxPadding(Rate rate);
   return case (rate)
	     R0: 1;
	     R1: 2;
	     R2: 3; 
	     R3: 5;
	     R4: 7;
	     R5: 11;
	     R6: 15;
	     R7: 17;
	  endcase;
endfunction      

// if the cur ele is the final byte, return the expected no of bits 
// remain in the sfifo at the end
function Bit#(5) nextSFIFORem(Bit#(5) x);
   return case (x)
	     0: 8;
	     4: 0;
	     8: 4;
	     default: 0;
	  endcase;
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

(* synthesize *)
module mkWiFiTXController(WiFiTXController);
   
   //state elements
   Reg#(Bool)                 busy <- mkReg(False);
   Reg#(TXState)           txState <- mkRegU;
   Reg#(Bit#(5))          sfifoRem <- mkRegU;
   Reg#(Bit#(5))             count <- mkRegU;
   Reg#(Bool)              rstSeed <- mkRegU;
   Reg#(Bool)            sendTail1 <- mkRegU;
   Reg#(TXVector)         txVector <- mkRegU;
   StreamFIFO#(24,5,Bit#(1)) sfifo <- mkStreamLFIFO; // size >= 16
   FIFO#(ScramblerMesg#(TXScramblerAndGlobalCtrl,ScramblerDataSz)) outQ;
   outQ <- mkSizedFIFO(2);
   
   // constants
   let sfifo_usage = sfifo.usage;
   let sfifo_free  = sfifo.free;

   // rules
   rule sendingHeader(busy && txState == SendHeader);
      let headers = makeHeader(txVector);
      Vector#(2,Bit#(8)) services = unpack(txVector.service); 
      let bypass = 12'hFFF;
      let seed = tagged Invalid;
      let fstSym = True;
      let rate = R0;
      let data = headers[1-count];
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      sfifo.enq(8,append(unpack(services[1-count]),replicate(0)));
      count <= (count == 0) ? 0 : count - 1;
      txState <= (count == 0) ? SendData : SendHeader;
      rstSeed <= True;
      sendTail1 <= False;
      $display("sendingHeader");
   endrule
   
   rule sendingData(busy && txState == SendData && 
		    sfifo_usage >= 12);
      let bypass = 12'h000;
      let seed = rstSeed ? tagged Valid 'b1101001: tagged Invalid;
      let fstSym = False;
      let rate = txVector.rate;
      let data = truncate(pack(sfifo.first));
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      sfifo.deq(12);
      count <= (count == 0) ? maxPadding(txVector.rate) : count - 1;
      rstSeed <= False;
      $display("sendingData");
   endrule
   
   rule sendingTail0(busy && txState == SendData &&
		     sfifo_usage < 12 && txVector.length == 0
		     && !sendTail1);
      let bypass = case (sfifoRem)
		      0: 12'h03F;
		      4: 12'h3F0;
		      8: 12'hF00;
		   endcase;
      let seed = tagged Invalid;
      let fstSym = False;
      let rate = txVector.rate;
      let data = truncate(pack(sfifo.first));
      data = case (sfifoRem)
		0: 0; 
		4: (data & 12'h00F); 
		8: (data & 12'h0FF);
	     endcase; 
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      if (sfifo_usage > 0) // only deq if > 0
	 sfifo.deq(sfifoRem);
      count <= (count == 0) ? maxPadding(txVector.rate) : count - 1;
      sendTail1 <= (sfifoRem == 8) ? True : False;
      txState <= (sfifoRem == 8) ? SendData : SendPadding;
      $display("sendingTail0");
   endrule
   
   rule sendingTail1(busy && txState == SendData && sendTail1);
      let bypass = 12'h003;
      let seed = tagged Invalid;
      let fstSym = False;
      let rate = txVector.rate;
      let data = 0;
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      count <= (count == 0) ? maxPadding(txVector.rate) : count - 1;
      txState <= SendPadding;
      $display("sendingTail1");      
   endrule
      
   rule sendingPadding(busy && txState == SendPadding);
      if (count == 0) // finish transmitter
	 busy <= False;
      else
	 begin
	    let bypass = 12'h000;
	    let seed = tagged Invalid;
	    let fstSym = False;
	    let rate = txVector.rate;
	    let data = 0;
	    let mesg = makeMesg(bypass,seed,fstSym,rate,data);
	    outQ.enq(mesg);
	    count <= count - 1;
	 end
      $display("sendingPadding");      
   endrule
   
   // methods
   method Action txStart(TXVector txVec) if (!busy);
      txVector <= txVec;
      busy <= True;
      txState <= SendHeader;
      count <= 1;
      sfifoRem <= 4; // start with 4 because of the 2 service bytes
      $display("txStart");
   endmethod
   
   method Action txData(Bit#(8) inData) 
      if (busy && txState == SendData && sfifo_free >= 8 &&
	  txVector.length > 0);
      sfifo.enq(8,append(unpack(inData),replicate(0)));
      txVector <= TXVector{rate: txVector.rate,
			   length: txVector.length - 1,
			   service: txVector.service,
			   power: txVector.power};
      sfifoRem <= nextSFIFORem(sfifoRem);
      $display("txData");
   endmethod
   
   method Action txEnd();
      busy <= False;
      sfifo.clear;
   endmethod
	    
   interface out = fifoToGet(outQ);   
endmodule 




