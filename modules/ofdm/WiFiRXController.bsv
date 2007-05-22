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
   interface Put#(EncoderMesg#(Bit#(0),DescramblerDataSz))                
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
   interface Put#(EncoderMesg#(Bit#(0),DescramblerDataSz))                
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
   Reg#(Bit#(1))     zeroCount <- mkRegU;  // count no of zeros symbol sent
   Reg#(Rate)        rxRate <- mkRegU;      // the packet rate for receiving
   Reg#(Bit#(16))    rxLength <- mkRegU;    // the remaining of data to be received (in terms of bits)
   
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
					 rate: (rxState == RX_HTAIL) ? R0 : rxRate};
      Symbol#(FFTIFFTSz,RXFPIPrec,RXFPFPrec) zeroSymbol = replicate(cmplx(0,0));
      outQ.enq(FFTMesg{control:rxCtrl, data: zeroSymbol});
      if (zeroCount == 0)
	 begin
	    zeroCount <= 1;
	 end
      else
	 begin
	    rxState <= (rxState == RX_HTAIL) ? RX_FEEDBACK : RX_IDLE;
	 end
   endrule 
   
   // interface methods
   interface Put inFromPreFFT;
      method Action put(SPMesgFromSync#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec) mesg) 
	 if (rxState != RX_HTAIL && rxState != RX_DTAIL);
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
	       if (rxLength < dbps) // last symbol
		  begin
		     rxState <= RX_DTAIL;
		  end
	       else
		  begin
		     rxLength <= rxLength - dbps;
		  end
	    end
	 endcase
      endmethod
   endinterface
 
   interface Put inFeedback;
      method Action put(Maybe#(RXFeedback) feedback) if (rxState == RX_FEEDBACK);
	 if (isValid(feedback)) // set the packet parameter
	    begin
	       let packetInfo = fromMaybe(?,feedback);
	       rxState <= RX_DATA;
	       rxRate  <= packetInfo.rate; 
	       rxLength <= (zeroExtend(packetInfo.length) + 2) << 3; // get the number of bits remained to received 
	    end
	 else // error in decoding package, return to idle
	    begin
	       rxState <= RX_IDLE; 
	    end
      endmethod
   endinterface

   interface outToPreDescrambler = fifoToGet(outQ);

endmodule

(* synthesize *)
module mkWiFiPreDescramblerRXController(WiFiPreDescramblerRXController);
   // state elements
   FIFO#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,Bit#(1))) inMesgQ <- mkLFIFO;
   FIFO#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) outMesgQ <- mkLFIFO;
   FIFO#(Maybe#(RXFeedback)) feedbackQ <- mkLFIFO;
   FIFO#(Bit#(12))           outLengthQ <- mkLFIFO;
   StreamFIFO#(24,5,Bit#(1)) streamQ <- mkStreamLFIFO;
   Reg#(RXCtrlState)         rxState <- mkReg(RX_DATA);
   Reg#(Bit#(1))             zeroCount <- mkReg(0);
   Reg#(Bool)                isGetSeed <- mkReg(False);
   Reg#(Maybe#(Bit#(ScramblerShifterSz))) seed <- mkReg(tagged Invalid);
   Reg#(Bit#(12))            rxLength <- mkRegU;

   // constants
   Bit#(5) vOutSz = fromInteger(valueOf(ViterbiOutDataSz));
   Bit#(5) dInSz  = fromInteger(valueOf(DescramblerDataSz));
   
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
   rule decodeHeader(rxState == RX_HEADER && streamQ.notEmpty(24));
      let header = pack(streamQ.first);
      if (checkParity(header))
	 begin
	    let rate = getRate(header);
	    let length = getLength(header);
	    outFeedbackQ.enq(tagged Valid RXFeedback{rate:rate,
						     length:length});
	    outLength.enq(length);
	    getSeed <= True;
	    rxLength <= length;
	 end
      else
	 begin
	    outFeedbackQ.enq(tagged Invalid);
	 end
      rxState <= RX_HTAIL;
      streamQ.deq(24);
   endrule
   
   // skip 2 symbols of zeros
   rule skipZeros(rxState == RX_HTAIL && streamQ.notEmpty(24));
      streamQ.deq(24);
      if (zeroCount == 0)
	 begin
	    zeroCount <= 1;
	 end
      else
	 begin
	    rxState <= RX_DATA;
	 end
   endrule
   
   rule getSeed(rxState == RX_DATA && isGetSeed && streamQ.notEmpty(12));
      seed <= tagged Valid ((pack(streamQ.first))[11:5]);
      isGetSeed <= False;
      streamQ.deq(12);
   endrule
   
   rule sendData(rxState == RX_DATA && !isGetSeed && streamQ.notEmpty(dInSz));
      let rxDCtrl = RXDescramblerCtrl{seed: seed, bypass: 0}; // descrambler ctrl, no bypass
      let rxGCtrl = RXGlobalCtrl{firstSymbol: isValid(seed), rate: ?};
      let rxCtrl = RXDescramblerAndGlobalCtrl{descramblerCtrl: rxDCtrl, length: rxLength, globalCtrl: rxGCtrl};
      seed <= tagged Invalid;
      outMesgQ.enq(DescramblerMesg{control: rxCtrl, data: tpl_2(split(pack(streamQ.first)))});
      streamQ.deq(dInSz);
   endrule
   
   rule processInMesgQ(streamQ.notFull(vOutSz));
      let mesg = inMesgQ.first;
      if (rxState == RX_DATA && mesg.control.firstSymbol)
	 begin
	    if (!streqmQ.notEmpty(vOutSz)) // all date from last packet has been processed
	       begin
		  rxState <= RX_HEADER;
		  zeroCount <= 0;
		  inMesgQ.deq;
		  streqmQ.enq(vOutSz,append(mesg.data,replicate(0)));
	       end
	 end
      else
	 begin
	    streamQ.enq(vOutSz,append(mesg.data,replicate(0)));
	 end
      endmethod
   endinterface

   // interface methods
   interface inFromPreDescrambler = fifoToPut(inMesgQ);     
   interface outToDescrambler = fifoToGet(outMesgQ);   
   interface outLength = fifoToGet(outLengthQ);   
   interface outFeedback = fifoToGet(outFeedbackQ);
endmodule 

(* synthesize *)
module mkWiFiPostDescramblerRXController(WiFiPostDescramblerRXController);
   // state elements
   FIFO#(Bit#(8)) outDataQ <- mkLFIFO;
   
   
   interface Put#(EncoderMesg#(Bit#(0),DescramblerDataSz))                
      inFromDescrambler;
      
   interface outData = fifoToGet(outDataQ);
endmodule

(* synthesize *)
module mkWiFiRXController(WiFiRXController);
   // state elements
   FIFO#(SPMesgFromSync#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec)) inFromPreFFTQ <- mkLFIFO;
   FIFO#(FFTMesg#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec)) outToPreDescramblerQ <- mkLFIFO;
   FIFO#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,Bit#(1))) inFromPreDescramblerQ <- mkLFIFO;
   FIFO#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) outToDescramblerQ <- mkLFIFO;
   FIFO#(EncoderMesg#(Bit#(0),DescramblerDataSz)) inFromDescramblerQ <- mkLFIFO;
   FIFO#(Bit#(12)) outLengthQ <- mkLFIFO;
   FIFO#(Bit#(8))  outDataQ <- mkLFIFO;
   Reg#(RXCtrlState) rxState <- mkReg(RX_IDLE);
   
   // rules
   rule processPreFFT(True);
      let mesg = inFromPreFFTQ.first;
      let outCtrl = RXGlobalCtrl{firstSymbol: False, rate:R1};
      inFromPreFFTQ.deq;
      outToPreDescramblerQ.enq(Mesg{control:outCtrl, data:mesg.data});
   endrule
	 
   rule processPreDescrambler(True);
      let mesg = inFromPreDescramblerQ.first;
      let descramblerCtrl = RXDescramblerCtrl{bypass: 0, seed: tagged Invalid};
      let outCtrl = RXDescramblerAndGlobalCtrl{descramblerCtrl:descramblerCtrl, globalCtrl: mesg.control};
      outToDescramblerQ.enq(Mesg{control:outCtrl, data:pack(mesg.data)});
   endrule
   
   rule processDescrambler(True);
      let mesg = inFromDescramblerQ.first;
      outDataQ.enq(truncate(pack(mesg.data)));
   endrule
         
   // methods
   interface inFromPreFFT = fifoToPut(inFromPreFFTQ);
   interface outToPreDescrambler = fifoToGet(outToPreDescramblerQ);
   interface inFromPreDescrambler = fifoToPut(inFromPreDescramblerQ);
   interface outToDescrambler = fifoToGet(outToDescramblerQ);
   interface inFromDescrambler = fifoToPut(inFromDescramblerQ);
   interface outLength = fifoToGet(outLengthQ);
   interface outData   = fifoToGet(outDataQ);
endmodule

/*
(* synthesize *)
module mkRX_Controller(WiFiRX_Controller);
   // states
   FIFOF#(Bit#(24)) inputQ <- mkSizedFIFOF(2);
   FIFOF#(FeedbackData) feedbackQ <- mkSizedFIFOF(2);
   FIFOF#(Bit#(12)) lengthQ <- mkSizedFIFOF(2);
   FIFOF#(DescramblerInData) outputQ <- mkSizedFIFOF(2);
   Reg#(Bit#(13)) frames_left <- mkRegU; //here actually mean octets left
   Reg#(Bit#(4))  zeros_to_skip <- mkRegU;
   Reg#(RCtrlState) state <- mkReg(WAITING_FOR_HEADER);
   Reg#(Rate) 	    rate <- mkRegU;
   Reg#(Bool) 	    isFirstFrame <- mkReg(False);

   // wires
   Bit#(24) input_data = inputQ.first();

   rule decodeHeader(state == WAITING_FOR_HEADER);
   begin
      Rate feedback_rate = case (input_data[1:0]) // check the first 2 bits (here is the least significant 2 bits because it is converted from a vector
			     2'b00: RNone;
			     2'b01: R4;  // supposed to be 2'b10, but reversed because of packing a vector
			     2'b10: R2;  // supposed to be 2'b01, but reversed because of packing a vector
			     2'b11: R1;
			   endcase; // case(input_data[23:22])
      Bit#(12) feedback_length = input_data[16:5];
      inputQ.deq();
      feedbackQ.enq(FeedbackData{rate: feedback_rate, length: feedback_length});
      lengthQ.enq(feedback_length);
      rate <= feedback_rate;
      frames_left <= zeroExtend(feedback_length) + 3; // + 3 because of 16 service bits (start) plus 6 tail bits
      state <= SKIPPING_ZEROS;
      zeros_to_skip <= 2;
      isFirstFrame <= True;
   end
   endrule

   rule skipZeros(state == SKIPPING_ZEROS);
   begin
      inputQ.deq();
      if (zeros_to_skip == 1) // last to skip
	begin
	   state <= (frames_left > 0) ? RECEIVING_DATA : WAITING_FOR_HEADER;
	   zeros_to_skip <= getNextZerosToSkip(rate);
	end
      else		 
	zeros_to_skip <= zeros_to_skip - 1;
   end
   endrule

   rule receiveData(state == RECEIVING_DATA);
   begin
      inputQ.deq();
      isFirstFrame <= False;
      outputQ.enq(tuple2(isFirstFrame,input_data));
      if (frames_left <= 3)
	begin
	   state <= SKIPPING_ZEROS;
	   zeros_to_skip <= zeros_to_skip + 2;
	   frames_left <= 0;
	end
      else
	begin
	   zeros_to_skip <= (zeros_to_skip == 0) ? getNextZerosToSkip(rate) : zeros_to_skip - 1;
	   frames_left <= frames_left - 3;
	end // else: !if(frames_left <= 3)
   end
   endrule

   method Action fromViterbi(Vector#(24, Bit#(1)) inData);
     inputQ.enq(pack(inData)); // note that when packed, a vector put the 0th element at least signficant bits 
   endmethod

   method ActionValue#(FeedbackData) toDetector();
     feedbackQ.deq();
     return(feedbackQ.first());
   endmethod

   method ActionValue#(Bit#(12)) toRX_MAC();
     lengthQ.deq();
     return(lengthQ.first());
   endmethod

   method ActionValue#(DescramblerInData) toDescrambler();
     outputQ.deq();
     return(outputQ.first());
   endmethod
   
endmodule
*/   

/*
   rule procinFromPreFFTQ(TRUE);
      let mesg = inFromPreFFTQ.first;
      case (preFFTState)
	 PreFFT_ZerosPreHeader:
	 begin
	    if (preFFTSkipZero == 0)
	       begin
		  let outCtrl = RXGlobalCtrl{firstSymbol: True, Rate: R0};
		  outToPreDescramblerQ.enq(Mesg{control: outCtrl, data: mesg.data});
		  preFFTSkipZero <= 1;
		  preFFTState <= SKIPPING_ZEROS;
	       end   
	    else
	       begin
		  let outCtrl = RXGlobalCtrl{firstSymbol: False, Rate: R0};
		  outToPreDescramblerQ.enq(Mesg{control: outCtrl, data: replicate(cmplx(0,0))});
		  preFFTSkipZero <= preFFTSkipZero - 1;
	       end
	 end
	 PreFFT_Forward:
	 begin
	    if (mesg.control.isNewPacket)
	       begin
		  let outCtrl = RXGlobalCtrl{firstSymbol: True, Rate: R0};
		  outToPreDescramblerQ.enq(Mesg{control: outCtrl, data: replicate(cmplx(0,0))});
		  preFFTSkipZero <= 1;
		  preFFTState <= PreFFT_ZerosPreHeader;
	       end   
	    else
	       begin
	    	  let outCtrl = RXGlobalCtrl{firstSymbol: False, Rate: rate};
		  outToPreDescramblerQ.enq(Mesg{control: outCtrl, data: mesg.data});
	       end
	 end
	 DROPPING_DATA:
	 begin
	    inFromPreFFTQ.deq;
	    if (mesg.control.isNewPacket)
	       begin
		  let outCtrl = RXGlobalCtrl{firstSymbol: True, Rate: R0};
		  outToPreDescramblerQ.enq(Mesg{control: outCtrl, data: mesg.data});
		  preFFTSkipZero <= 1;
		  preFFTState <= SKIPPING_ZEROS;
	       end   
	 end
	 
	 
	 
      inFromPreFFTQ.deq;
      if (mesg.control.isNewPacket)
	 begin
	    let outCtrl = RXGlobalCtrl{firstSymbol: True, Rate: R0};
	    outToPreDescramblerQ.enq(Mesg{control: outCtrl, data: mesg.data});
	    preFFTSkipZero <= 1;
	    preFFTState <= SKIPPING_ZEROS;
	 end
      else
	 if (preFFTState == RECEIVING_DATA)
	    begin
	       let outCtrl = RXGlobalCtrl{firstSymbol: True, Rate: R0};
	       outToPreDescramblerQ.enq(Mesg{control: outCtrl, data: mesg.data});
*/	       

