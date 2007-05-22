import Complex::*;
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
// import Parameters::*;

typedef struct{
   Rate     rate;
   Bit#(12) length;
} RXFeedback deriving (Bits, Eq);

interface WiFiPreFFTRXController;
   interface Put#(SPMesgFromSync#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec)) 
      inFromPreFFT;
   interface Get#(FFTMesg#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec))   
      outToPreDescrambler;
   interface Put#(Maybe#(RXFeedback)) inFeedback;
endinterface

interface WiFiPreDescramblerRXController;
   interface Put#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,Bit#(1)))    
      inFromPreDescrambler;
   interface Get#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) 
      outToDescrambler;
   interface Get#(Maybe#(RXFeedback)) outFeedback;
   interface Get#(Bit#(12))   outLength;
endinterface

interface WiFiPostDescramblerRXController;
   interface Put#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz))                
      inFromDescrambler;
   interface Get#(Bit#(8))  outData;
endinterface      

interface WiFiRXController;
   interface Put#(SPMesgFromSync#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec)) 
      inFromPreFFT;
   interface Get#(FFTMesg#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec))   
      outToPreDescrambler;
   interface Put#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,Bit#(1)))    
      inFromPreDescrambler;
   interface Get#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) 
      outToDescrambler;
   interface Put#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz))                
      inFromDescrambler;
   interface Get#(Bit#(12)) outLength;
   interface Get#(Bit#(8))  outData;
endinterface
      
typedef enum{
   RX_IDLE,     // idle
   RX_HEADER,   // decoding header
   RX_HTAIL,    // sending zeros after header
   RX_FEEDBACK, // waiting for feedback
   RX_DATA,     // decoding data
   RX_DTAIL     // sending zeros after data
} RXCtrlState deriving(Eq,Bits);

(* synthesize *)
module mkWiFiPreFFTRXController(WiFiPreFFTRXController);
   // state elements
   FIFO#(FFTMesg#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec)) outQ <- mkLFIFO;
   Reg#(RXCtrlState) rxState <- mkReg(RX_IDLE); // the current state
   Reg#(Bit#(3))     zeroCount <- mkRegU;       // count no of zeros symbol sent
   Reg#(Rate)        rxRate <- mkRegU;          // the packet rate for receiving
   Reg#(Bit#(16))    rxLength <- mkRegU;        // the remaining of data to be received (in terms of bits)
   
   // constants
   // data bis per ofdm symbol 
   Bit#(16) dbps = case (rxRate)
		      R0: 24;
		      R1: 36;
		      R2: 48;
		      R3: 72;
		      R4: 96;
		      R5: 144;
		      R6: 192;
		      R7: 216;
		   endcase;
   
   // rules
   // send 2 extra symbol of zeros to push out data from vitebri (also reset the viterbi state)
   rule sendZeros(rxState == RX_HTAIL || rxState == RX_DTAIL);
      RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: (rxState == RX_HTAIL) ? True : False, 
					 rate: R0};
      Symbol#(FFTIFFTSz,RXFPIPrec,RXFPFPrec) zeroSymbol = replicate(cmplx(0,0));
      outQ.enq(FFTMesg{control:rxCtrl, data: zeroSymbol});
      if (zeroCount < 4)
	 begin
	    zeroCount <= zeroCount + 1;
	 end
      else
	 begin
	    rxState <= (rxState == RX_HTAIL) ? RX_FEEDBACK : RX_IDLE;
	 end
      $display("PreFFTRXCtrllr sendZeros rxState:%d rxLength:%d",rxState,rxLength);
   endrule 
   
   // interface methods
   interface Put inFromPreFFT;
      method Action put(SPMesgFromSync#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec) mesg) 
	 if (rxState != RX_HTAIL && rxState != RX_DTAIL && rxState != RX_FEEDBACK);
	 case (rxState)
	    RX_IDLE: 
	    begin
	       if (mesg.control) // only process if it is a new packet, otherwise, drop it
		  begin	
		     zeroCount <= 0;
		     RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: True, 
							rate: R0};
		     outQ.enq(FFTMesg{control:rxCtrl, data: mesg.data});
		     rxState <= RX_HTAIL;
		  end  
	       end
	    RX_DATA:
	    begin
	       RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: False, 
						  rate: rxRate};
	       outQ.enq(FFTMesg{control:rxCtrl, data: mesg.data});
	       if (rxLength <= dbps) // last symbol
		  begin
		     rxState <= RX_DTAIL;
		     zeroCount <= 0;
		  end
	       else
		  begin
		     rxLength <= rxLength - dbps;
		  end
	    end
	 endcase
	 $display("PreFFTRXCtrllr inFromPreFFT rxState:%d rxLength:%d",rxState,rxLength);
      endmethod
   endinterface
 
   interface Put inFeedback;
      method Action put(Maybe#(RXFeedback) feedback) if (rxState == RX_FEEDBACK);
	 if (isValid(feedback)) // set the packet parameter
	    begin
	       let packetInfo = fromMaybe(?,feedback);
	       rxState <= RX_DATA;
	       rxRate  <= packetInfo.rate; 
	       rxLength <= ((zeroExtend(packetInfo.length) + 2) << 3) + 6; // no of bits to be received = (16+8*length+6) 
	    end
	 else // error in decoding package, return to idle
	    begin
	       rxState <= RX_IDLE; 
	    end
	 $display("PreFFTRXCtrllr inFeedback rxState:%d rxLength:%d",rxState,rxLength);
      endmethod
   endinterface

   interface outToPreDescrambler = fifoToGet(outQ);

endmodule

(* synthesize *)
module mkWiFiPreDescramblerRXController(WiFiPreDescramblerRXController);
   // state elements
   FIFO#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,Bit#(1))) inMesgQ <- mkLFIFO;
   FIFO#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) outMesgQ <- mkLFIFO;
   FIFO#(Maybe#(RXFeedback)) outFeedbackQ <- mkLFIFO;
   FIFO#(Bit#(12))           outLengthQ <- mkLFIFO;
   StreamFIFO#(24,5,Bit#(1)) streamQ <- mkStreamLFIFO;
   Reg#(RXCtrlState)         rxState <- mkReg(RX_DATA);
   Reg#(Bit#(3))             zeroCount <- mkReg(0);
   Reg#(Bool)                isGetSeed <- mkReg(False);
   Reg#(Maybe#(Bit#(ScramblerShifterSz))) seed <- mkReg(tagged Invalid);
   Reg#(Bit#(12))            rxLength <- mkRegU;

   // constants
   Bit#(5) vOutSz = fromInteger(valueOf(ViterbiOutDataSz));
   Bit#(5) dInSz  = fromInteger(valueOf(DescramblerDataSz));
   let streamQ_usage = streamQ.usage;
   let streamQ_free  = streamQ.free;
   
   // functions
   function Rate getRate(Bit#(24) header);
      return case (header[3:0])
		4'b1011: R0;
		4'b1111: R1;
		4'b1010: R2; 
		4'b1110: R3;
		4'b1001: R4;
		4'b1101: R5;
		4'b1000: R6;
		4'b1100: R7;
		default: R0;
	     endcase;
   endfunction
   
   function Bit#(12) getLength(Bit#(24) header);
      return header[16:5];
   endfunction
   
   function Bool checkParity(Bit#(24) header);
      return header[17:17] == getParity(header[16:0]);
   endfunction
   
   // rules
   rule decodeHeader(rxState == RX_HEADER && streamQ_usage >= 24);
      let header = pack(streamQ.first);
      if (checkParity(header))
	 begin
	    let rate = getRate(header);
	    let length = getLength(header);
	    outFeedbackQ.enq(tagged Valid RXFeedback{rate:rate,
						     length:length});
	    outLengthQ.enq(length);
	    isGetSeed <= True;
	    rxLength <= length;
	 end
      else
	 begin
	    outFeedbackQ.enq(tagged Invalid);
	 end
      rxState <= RX_HTAIL;
      streamQ.deq(24);
      $display("PreDescramblerRXCtrllr decodeHeader rxState:%d rxLength:%d",rxState,rxLength);
   endrule
   
   // skip 2 symbols of zeros
   rule skipZeros(rxState == RX_HTAIL && streamQ_usage >= 24);
      streamQ.deq(24);
      if (zeroCount < 4)
	 begin
	    zeroCount <= zeroCount + 1;
	 end
      else
	 begin
	    rxState <= RX_DATA;
	 end
      $display("PreDescramblerRXCtrllr skipZeros rxState:%d rxLength:%d",rxState,rxLength);
   endrule
   
   rule getSeed(rxState == RX_DATA && isGetSeed && streamQ_usage >= 12);
      seed <= tagged Valid (reverseBits((pack(streamQ.first))[11:5]));
      isGetSeed <= False;
      streamQ.deq(12);
      $display("PreDescramblerRXCtrllr getSeed rxState:%d rxLength:%d",rxState,rxLength);      
   endrule
   
   rule sendData(rxState == RX_DATA && !isGetSeed && streamQ_usage >= dInSz);
      let rxDCtrl = RXDescramblerCtrl{seed: seed, bypass: 0}; // descrambler ctrl, no bypass
      let rxGCtrl = RXGlobalCtrl{firstSymbol: isValid(seed), rate: ?};
      let rxCtrl = RXDescramblerAndGlobalCtrl{descramblerCtrl: rxDCtrl, length: rxLength, globalCtrl: rxGCtrl};
      seed <= tagged Invalid;
      outMesgQ.enq(DescramblerMesg{control: rxCtrl, data: pack(take(streamQ.first))});
      streamQ.deq(dInSz);
      $display("PreDescramblerRXCtrllr sendData rxState:%d rxLength:%d",rxState,rxLength);
   endrule
   
   rule processInMesgQ(streamQ_free >= vOutSz);
      let mesg = inMesgQ.first;
      if (rxState == RX_DATA && mesg.control.firstSymbol)
	 begin
	    if (streamQ_usage == 0) // all date from last packet has been processed
	       begin
		  rxState <= RX_HEADER;
		  zeroCount <= 0;
		  inMesgQ.deq;
		  streamQ.enq(vOutSz,append(mesg.data,replicate(0)));
	       end
	 end
      else
	 begin
	    inMesgQ.deq;
	    streamQ.enq(vOutSz,append(mesg.data,replicate(0)));
	 end
      $display("PreDescramblerRXCtrll processInMsgQ rxState:%d rxLength:%d",rxState,rxLength);      
   endrule

   // interface methods
   interface inFromPreDescrambler = fifoToPut(inMesgQ);     
   interface outToDescrambler = fifoToGet(outMesgQ);   
   interface outLength = fifoToGet(outLengthQ);   
   interface outFeedback = fifoToGet(outFeedbackQ);
endmodule 

(* synthesize *)
module mkWiFiPostDescramblerRXController(WiFiPostDescramblerRXController);
   // state elements
   FIFO#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) inMesgQ <- mkLFIFO;
   FIFO#(Bit#(8)) outDataQ <- mkLFIFO;
   StreamFIFO#(24,5,Bit#(1)) streamQ <- mkStreamLFIFO; // descramblerdatasz must be factor of 12
   Reg#(Bit#(12)) rxLength <- mkRegU; // no of bytes remains to be received
   Reg#(Bool)     drop4b   <- mkRegU; // drop the first 4 bits?
   Reg#(RXCtrlState) rxState <- mkReg(RX_IDLE);
   
   // constants
   Bit#(5) dInSz = fromInteger(valueOf(DescramblerDataSz));
   let streamQ_usage = streamQ.usage;
   let streamQ_free  = streamQ.free;
   
   // rules
   rule processInMesgQ(streamQ_free >= dInSz);
      let mesg = inMesgQ.first;
      inMesgQ.deq;
      if ((rxState == RX_IDLE && mesg.control.globalCtrl.firstSymbol) || rxState != RX_IDLE)
	 begin
	    if (rxState == RX_IDLE)
	       begin
		  rxState <= RX_DATA;
		  drop4b <= True;
		  rxLength <= mesg.control.length;
	       end
	    streamQ.enq(dInSz,append(unpack(mesg.data),replicate(0)));
	 end
      else
	 begin
	    streamQ.clear;
	 end
      $display("PostDescramblerRXCtrllr processInMesgQ rxState:%d rxLength:%d",rxState,rxLength);      
   endrule
   
   rule processStreamQ(streamQ_usage >= 8);
      Bit#(8) outData = truncate(pack(streamQ.first));
      Bit#(5) deqSz = drop4b ? 4 : 8;
      drop4b <= False;
      streamQ.deq(deqSz);
      if (!drop4b)
	 begin
	    outDataQ.enq(outData);
	    if (rxLength > 1)
	       begin
		  rxLength <= rxLength - 1;
	       end
	    else
	       begin
		  rxState <= RX_IDLE;
	       end
	 end
      $display("PostDescramblerRXCtrllr processStreamQ rxState:%d rxLength:%d",rxState,rxLength);      
   endrule
   
   // interface methods
   interface inFromDescrambler = fifoToPut(inMesgQ);
   interface outData = fifoToGet(outDataQ);
endmodule

(* synthesize *)
module mkWiFiRXController(WiFiRXController);
   // state elements
   let preFFTCtrllr          <- mkWiFiPreFFTRXController;
   let preDescramblerCtrllr  <- mkWiFiPreDescramblerRXController;
   let postDescramblerCtrllr <- mkWiFiPostDescramblerRXController;
   
   // mkConnections
   mkConnection(preDescramblerCtrllr.outFeedback,preFFTCtrllr.inFeedback);
   
   // methods
   interface inFromPreFFT = preFFTCtrllr.inFromPreFFT;
   interface outToPreDescrambler = preFFTCtrllr.outToPreDescrambler;
   interface inFromPreDescrambler = preDescramblerCtrllr.inFromPreDescrambler;
   interface outToDescrambler = preDescramblerCtrllr.outToDescrambler;
   interface inFromDescrambler = postDescramblerCtrllr.inFromDescrambler;
   interface outLength = preDescramblerCtrllr.outLength;
   interface outData   = postDescramblerCtrllr.outData;
endmodule

