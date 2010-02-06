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
import ofdm_tx_controller::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import Parameters::*;

typedef TXVector RXFeedback;

interface WiMAXPreFFTRXController;
   interface Put#(SPMesgFromSync#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec)) 
      inFromPreFFT;
   interface Get#(FFTMesg#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec))   
      outToPreDescrambler;
   interface Put#(RXFeedback) inFeedback;
endinterface

interface WiMAXPreDescramblerRXController;
   interface Put#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,Bit#(1)))    
      inFromPreDescrambler;
   interface Get#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) 
      outToDescrambler;
   interface Get#(Bit#(11))   outLength;
   interface Put#(RXFeedback) inFeedback;
endinterface

interface WiMAXPostDescramblerRXController;
   interface Put#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz))                
      inFromDescrambler;
   interface Get#(Bit#(8))  outData;
endinterface      

interface WiMAXRXController;
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
   interface Put#(RXFeedback) inFeedback;
   interface Get#(Bit#(11)) outLength;
   interface Get#(Bit#(8))  outData;
endinterface
      
typedef enum{
   RX_IDLE,     // idle
   RX_DATA,     // decoding data
   RX_DTAIL     // sending zeros after data
} RXCtrlState deriving(Eq,Bits);

// (* synthesize *)
module mkWiMAXPreFFTRXController(WiMAXPreFFTRXController);
   // state elements
   FIFO#(FFTMesg#(RXGlobalCtrl,FFTIFFTSz,RXFPIPrec,RXFPFPrec)) outQ <- mkLFIFO;
   Reg#(RXCtrlState) rxState <- mkReg(RX_IDLE); // the current state
   Reg#(Bit#(3))     zeroCount <- mkRegU;       // count no of zeros symbol sent
   Reg#(Rate)        rxRate <- mkRegU;          // the packet rate for receiving
   Reg#(Bit#(11))    rxLength <- mkRegU;        // the remaining of data to be received (in terms of bits)
   FIFO#(RXFeedback) rxVecQ <- mkSizedFIFO(4);  // to be save
       
   // constants
   // uncoded data bytes per ofdm symbol 
   function Bit#(11) getDBPS(Rate rate);
      return case (rate) 
		R0: 12;
		R1: 24;
		R2: 36;
		R3: 48;
		R4: 72;
		R5: 96;
		R6: 108;
	     endcase;
   endfunction
   let dbps = getDBPS(rxRate);
   
   // rules
   // send 2 extra symbol of zeros to push out data from vitebri (also reset the viterbi state)
   rule sendZeros(rxState == RX_DTAIL);
      RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: False,
					 cpSize: CP0,
					 rate: R0};
      Symbol#(FFTIFFTSz,RXFPIPrec,RXFPFPrec) zeroSymbol = replicate(cmplx(0,0));
      outQ.enq(FFTMesg{control:rxCtrl, data: zeroSymbol});
      if (zeroCount < 4)
	 begin
	    zeroCount <= zeroCount + 1;
	 end
      else
	 begin
	    rxState <= RX_IDLE;
	 end
      $display("PreFFTRXCtrllr sendZeros rxState:%d rxLength:%d",rxState,rxLength);
   endrule 
   
   // interface methods
   interface Put inFromPreFFT;
      method Action put(SPMesgFromSync#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec) mesg) 
	 if (rxState != RX_DTAIL);
	 case (rxState)
	    RX_IDLE: 
	    begin
	       if (mesg.control) // only process if it is a new packet, otherwise, drop it
		  begin	
		     let rxVec = rxVecQ.first;
		     let checkLen = getDBPS(rxVec.rate) - 1;
		     if (rxVec.length > checkLen)
			begin
		   	   rxRate <= rxVec.rate;
			   rxLength <= rxVec.length - checkLen;
			   rxState <= RX_DATA;
			end
		     RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: True,
							cpSize: CP0,
							rate: rxVec.rate};
		     outQ.enq(FFTMesg{control:rxCtrl, data: mesg.data});
		     rxVecQ.deq;
		  end  
	       end
	    RX_DATA:
	    begin
	       RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: False,
						  cpSize: CP0,
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
 
   interface inFeedback = fifoToPut(rxVecQ);
   interface outToPreDescrambler = fifoToGet(outQ);

endmodule

// (* synthesize *)
module mkWiMAXPreDescramblerRXController(WiMAXPreDescramblerRXController);
   // state elements
   FIFO#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) outMesgQ <- mkLFIFO;
   FIFO#(RXFeedback)         rxVecQ <- mkSizedFIFO(4);
   FIFO#(Bit#(11))       outLengthQ <- mkLFIFO;
   Reg#(Bit#(11))          rxLength <- mkRegU;
   Reg#(Bit#(7))              count <- mkReg(0);
   
   // constants
   Bit#(7) vDataSz = fromInteger(valueOf(ViterbiOutDataSz)/8);
   
   // interface methods
   interface Put inFromPreDescrambler;
      method Action put(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,Bit#(1)) mesg);
	 if (mesg.control.firstSymbol && count == 0)
	    begin
	       let rxVec = rxVecQ.first; 
	       let dCtrl = RXDescramblerCtrl{bypass: 0, 
					     seed: tagged Valid (makeSeed(rxVec))};
	       let rCtrl = RXDescramblerAndGlobalCtrl{descramblerCtrl: dCtrl,
						      length: rxVec.length,
						      isNewPacket: True};
	       Bit#(DescramblerDataSz) data = pack(mesg.data);
	       let mesg = DescramblerMesg{control: rCtrl,
					  data: data};
	       outMesgQ.enq(mesg);
	       outLengthQ.enq(rxVec.length);
	       rxLength <= rxVec.length; 
	       rxVecQ.deq;
	       count <= maxPadding(rxVec.rate) - vDataSz;	       
	    end
	 else
	    begin
	       let dCtrl = RXDescramblerCtrl{bypass: 0, 
					     seed: tagged Invalid};
	       let rCtrl = RXDescramblerAndGlobalCtrl{descramblerCtrl: dCtrl,
						      length: rxLength,
						      isNewPacket: False};
	       Bit#(DescramblerDataSz) data = pack(mesg.data);
	       let mesg = DescramblerMesg{control: rCtrl,
					  data: data};
	       outMesgQ.enq(mesg);
	       if (count > 0)
		  count <= count - vDataSz;	       
	    end
	 $display("PreDescramlerRXCtrllr inFromPreDesc rxLength:%d",rxLength);
      endmethod
   endinterface
   
   interface outToDescrambler = fifoToGet(outMesgQ);   
   interface outLength = fifoToGet(outLengthQ);   
   interface inFeedback = fifoToPut(rxVecQ);
endmodule 

// (* synthesize *)
module mkWiMAXPostDescramblerRXController(WiMAXPostDescramblerRXController);
   // state elements
   FIFO#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) inMesgQ <- mkLFIFO;
   FIFO#(Bit#(8)) outDataQ <- mkLFIFO;
   StreamFIFO#(32,6,Bit#(1)) streamQ <- mkStreamLFIFO;
   Reg#(Bit#(11)) rxLength <- mkRegU; // no of bytes remains to be received
   Reg#(RXCtrlState) rxState <- mkReg(RX_IDLE);
   
   // constants
   Bit#(6) dInSz = fromInteger(valueOf(DescramblerDataSz));
   let streamQ_usage = streamQ.usage;
   let streamQ_free  = streamQ.free;
   
   // rules
   rule processInMesgQ(streamQ_free >= dInSz);
      let mesg = inMesgQ.first;
      inMesgQ.deq;
      if ((rxState == RX_IDLE && mesg.control.isNewPacket) || rxState != RX_IDLE)
	 begin
	    if (rxState == RX_IDLE)
	       begin
		  rxState <= RX_DATA;
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
      streamQ.deq(8);
      outDataQ.enq(outData);
      if (rxLength > 1)
	 begin
	    rxLength <= rxLength - 1;
	 end
      else
	 begin
	    rxState <= RX_IDLE;
	 end
      $display("PostDescramblerRXCtrllr processStreamQ rxState:%d rxLength:%d",rxState,rxLength);      
   endrule
   
   // interface methods
   interface inFromDescrambler = fifoToPut(inMesgQ);
   interface outData = fifoToGet(outDataQ);
endmodule

// (* synthesize *)
module mkWiMAXRXController(WiMAXRXController);
   // state elements
   let preFFTCtrllr          <- mkWiMAXPreFFTRXController;
   let preDescramblerCtrllr  <- mkWiMAXPreDescramblerRXController;
   let postDescramblerCtrllr <- mkWiMAXPostDescramblerRXController;
   
   // methods
   interface inFromPreFFT = preFFTCtrllr.inFromPreFFT;
   interface outToPreDescrambler = preFFTCtrllr.outToPreDescrambler;
   interface inFromPreDescrambler = preDescramblerCtrllr.inFromPreDescrambler;
   interface outToDescrambler = preDescramblerCtrllr.outToDescrambler;
   interface inFromDescrambler = postDescramblerCtrllr.inFromDescrambler;
   interface outLength = preDescramblerCtrllr.outLength;
   interface outData   = postDescramblerCtrllr.outData;
      
   interface Put inFeedback;
      method Action put(RXFeedback feedback);
	 preFFTCtrllr.inFeedback.put(feedback);
	 preDescramblerCtrllr.inFeedback.put(feedback);
      endmethod    
   endinterface
      
endmodule

