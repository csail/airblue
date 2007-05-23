import Connectable::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

import ofdm_common::*;
import ofdm_parameters::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import LibraryFunctions::*;
// import Parameters::*;
// import StreamFIFO::*;

typedef struct{
   Bit#(12) length;  // data to send in bytes
   Rate     rate;    // data rate 
   Bit#(16) service; // service bits, should be all 0s
   Bit#(3)  power;   // transmit power level (not affecting baseband)
} TXVector deriving (Eq, Bits);

typedef enum{ SendHeader, EnqService, SendData, SendPadding }
        TXState deriving (Eq, Bits);

interface WiFiTXController;
   method Action txStart(TXVector txVec);
   method Action txData(Bit#(8) inData);
   method Action txEnd();
   interface Get#(ScramblerMesg#(TXScramblerAndGlobalCtrl,
				 ScramblerDataSz)) out;
endinterface
      
function Bit#(24) makeHeader(TXVector txVec);
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
      return data;   
endfunction

// get maximum number of padding (basic unit is bit) required for each rate
function Bit#(8) maxPadding(Rate rate);
   Bit#(8) scramblerDataSz = fromInteger(valueOf(ScramblerDataSz)); // must be a factor of 12
   return case (rate)
	     R0: 24 - scramblerDataSz;
	     R1: 36 - scramblerDataSz;
	     R2: 48 - scramblerDataSz; 
	     R3: 72 - scramblerDataSz;
	     R4: 96 - scramblerDataSz;
	     R5: 144 - scramblerDataSz;
	     R6: 192 - scramblerDataSz;
	     R7: 216 - scramblerDataSz;
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
   Reg#(Bit#(8))             count <- mkRegU;
   Reg#(Bool)              rstSeed <- mkRegU;
   Reg#(Bool)              addTail <- mkRegU;
   Reg#(Bool)              addZero <- mkRegU;
   Reg#(TXVector)         txVector <- mkRegU;
   StreamFIFO#(24,5,Bit#(1)) sfifo <- mkStreamLFIFO; // size >= 16
   FIFO#(ScramblerMesg#(TXScramblerAndGlobalCtrl,ScramblerDataSz)) outQ;
   outQ <- mkSizedFIFO(2);
   
   // constants
   let sfifo_usage = sfifo.usage;
   let sfifo_free  = sfifo.free;
   Bit#(5) scramblerDataSz = fromInteger(valueOf(ScramblerDataSz));

   // rules
   rule sendHeader(busy && txState == SendHeader && sfifo.usage >= scramblerDataSz);
      Bit#(ScramblerDataSz) bypass = maxBound; 
      let seed = tagged Invalid;
      let fstSym = True;
      let rate = R0;
      Bit#(ScramblerDataSz) data = pack(take(sfifo.first));
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      sfifo.deq(scramblerDataSz);
      if (sfifo.usage == scramblerDataSz)
	 begin
	    txState <= EnqService;
	 end
      rstSeed <= True;
      addTail <= True;
      addZero <= True;
      $display("TXCtrl fires sendHeader");
   endrule
   
   rule enqService(busy && txState == EnqService);
      sfifo.enq(16,append(unpack(txVector.service),replicate(0)));
      rstSeed <= True;
      txState <= SendData;
      $display("TXCtrl fires enqService");
   endrule
   
   rule sendData(busy && txState == SendData && 
		 sfifo_usage >= scramblerDataSz && 
		 addZero);
      Bit#(ScramblerDataSz) bypass = 0;
      let seed = rstSeed ? 
                 tagged Valid 'b1101001 : 
                 tagged Invalid;
      let fstSym = False;
      let rate = txVector.rate;
      Bit#(ScramblerDataSz) data = pack(take(sfifo.first));
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      sfifo.deq(scramblerDataSz);
      count <= (count == 0) ? 
               maxPadding(txVector.rate) : 
               count - zeroExtend(scramblerDataSz);
      rstSeed <= False;
      $display("TXCtrl fires sendData");
   endrule
     
   rule insTail(busy && txState == SendData &&
		sfifo_usage < scramblerDataSz && 
		txVector.length == 0 && addTail &&
		addZero); 
      sfifo.enq(6,replicate(0));
      addTail <= False;
      $display("TXCtrl fires insTail");
   endrule
   
   rule insZero(busy && txState == SendData &&
		sfifo_usage < scramblerDataSz && 
		!addTail && addZero); 
      let enqSz = scramblerDataSz - sfifo_usage;
      if (sfifo_usage > 0) // only add zero when usage > 0
	 sfifo.enq(enqSz,replicate(0));
      addZero <= False;
      $display("TXCtrl fires insZero");
   endrule   
   
   rule sendLast(busy && txState == SendData &&
		 !addZero);
      Bit#(ScramblerDataSz) bypass = 0;
      let seed = tagged Invalid;
      let fstSym = False;
      let rate = txVector.rate;
      Bit#(ScramblerDataSz) data = truncate(pack(sfifo.first));
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      if (sfifo_usage > 0) // only send if usage > 0
	 begin
	    outQ.enq(mesg);
	    sfifo.deq(sfifo_usage);
	    count <= (count == 0) ? 
                     maxPadding(txVector.rate) : 
		     count - zeroExtend(scramblerDataSz);
	 end
      txState <= SendPadding;
      $display("TXCtrl fires sendLast");
   endrule
   
   rule sendPadding(busy && txState == SendPadding && count > 0);
      Bit#(ScramblerDataSz) bypass = 0;
      let seed = tagged Invalid;
      let fstSym = False;
      let rate = txVector.rate;
      Bit#(ScramblerDataSz) data = 0;
      let mesg = makeMesg(bypass,seed,fstSym,rate,data);
      outQ.enq(mesg);
      count <= count - zeroExtend(scramblerDataSz);
      $display("TXCtrl fires sendPadding");      
   endrule
   
   rule becomeIdle(busy && txState == SendPadding && count == 0);
      busy <= False;
      $display("TXCtrl fires becomeIdle");
   endrule
   
   // methods
   method Action txStart(TXVector txVec) if (!busy);
      txVector <= txVec;
      busy <= True;
      txState <= SendHeader;
      count <= 0;
      sfifo.enq(24,append(unpack(makeHeader(txVec)),replicate(0)));
      $display("TXCtrl fires txStart");
   endmethod
   
   method Action txData(Bit#(8) inData) 
      if (busy && txState == SendData && sfifo_free >= 8 &&
	  txVector.length > 0);
      sfifo.enq(8,append(unpack(inData),replicate(0)));
      txVector <= TXVector{rate: txVector.rate,
			   length: txVector.length - 1,
			   service: txVector.service,
			   power: txVector.power};
      $display("TXCtrl fires txData");
   endmethod
   
   method Action txEnd();
      busy <= False;
      sfifo.clear;
   endmethod
	    
   interface out = fifoToGet(outQ);   
endmodule 




