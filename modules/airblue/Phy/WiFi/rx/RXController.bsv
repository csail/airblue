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

import Complex::*;
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

// `include "../WiFiFPGA/Macros.bsv"

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/c_bus_utils.bsh"


//import TXController::*;

// typedef struct{
//    Rate      rate;
//    PhyPacketLength length;
// } RXVector deriving (Bits, Eq);

// typedef struct{
//    HeaderInfo header;
//    Bool       is_trailer;
// } RXVector deriving (Bits, Eq);

// typedef union tagged {
//    data_t Data;    // correct decode data of data_t
//    err_t  Error;  // incorrect decode, error info as err_t 
// } Feedback#(type data_t, type err_t) deriving (Bits, Eq);

// typedef enum {
//    ParityError,
//    RateError,
//    ZeroFieldError
// } RXVectorDecodeError deriving (Bits,Eq);

// typedef enum {
//   LongSync,
//   HeaderDecoded,
//   DataComplete,
//   Abort
// } RXExternalFeedback deriving (Bits,Eq);

// function Bool validFeedback(Feedback#(d,e) feedback);
//    let res = case (feedback) matches
//                 tagged Data .x: True;
//                 default: False;
//              endcase;
//    return res;
// endfunction

// function a getDataFromFeedback(a d_res, Feedback#(a,e) feedback);
//    let res = case (feedback) matches
//                 tagged Data .x: x;
//                 default: d_res;
//              endcase;
//    return res;
// endfunction

// function e getErrorFromFeedback(e d_res, Feedback#(a,e) feedback);
//    let res = case (feedback) matches
//                 tagged Error .x: x;
//                 default: d_res;
//              endcase;
//    return res;
// endfunction
   
// function Feedback#(RXVector,RXVectorDecodeError) decodeHeader(Header header);
   
//    RXVector vec;
   
//    function Maybe#(Rate) getRate(Header header);
//       return case (header[3:0])
// 		4'b1011: tagged Valid R0;
// 		4'b1111: tagged Valid R1;
// 		4'b1010: tagged Valid R2; 
// 		4'b1110: tagged Valid R3;
// 		4'b1001: tagged Valid R4;
// 		4'b1101: tagged Valid R5;
// 		4'b1000: tagged Valid R6;
// 		4'b1100: tagged Valid R7;
// 		default: tagged Invalid;
// 	     endcase;
//    endfunction

//    vec.header.rate        = fromMaybe(?,getRate(header));
//    vec.header.length      = header[16:5]; 
//    vec.header.has_trailer = ?;
//    vec.header.power       = ?;
//    vec.header.src_addr    = ?;
//    vec.header.dst_addr    = ?;
//    vec.header.uid         = ?;
//    vec.is_trailer         = unpack(header[4:4]);
//    let parity_err         = header[17:17] != getParity(header[16:0]); // parity check
//    let rate_err           = !isValid(getRate(header));
//    let zero_field_err     = header[23:18] != 0;  
//    let err                = parity_err ? ParityError : (rate_err ? RateError : ZeroFieldError); 
//    let is_err             = parity_err || rate_err || zero_field_err;
//    return is_err ? tagged Error err : tagged Data vec;   
// endfunction

interface PreDemapperRXController;
   interface Put#(DemapperMesg#(Bool,DemapperInDataSz,RXFPIPrec,RXFPFPrec)) 
      inFromPreDemapper;
   interface Get#(DemapperMesg#(RXGlobalCtrl,DemapperInDataSz,RXFPIPrec,RXFPFPrec))   
      outToPreDescrambler;
   interface Put#(Feedback#(RXVector,RXVectorDecodeError)) inFeedback;
   interface Get#(RXExternalFeedback) outFeedback;
   method    Action abortReq; // request to abort from MAC
   interface Get#(Bit#(0)) abortAck; // finish abort
endinterface

interface PreDescramblerRXController;
   interface Put#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,ViterbiOutput))    
      inFromPreDescrambler;
   interface Get#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) 
      outToDescrambler;
   interface Get#(Feedback#(RXVector,RXVectorDecodeError)) outFeedback;
   interface Get#(RXVector)   outRXVector;
   `ifdef SOFT_PHY_HINTS
   interface Get#(Bit#(8))  outSoftPhyHints;
   `endif   
   method    Action abortReq;
endinterface

interface PostDescramblerRXController;
   method Action abortReq;
   interface Put#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz))                
      inFromDescrambler;
   interface Get#(Bit#(8))  outData;
endinterface      

interface RXController;
   interface Put#(DemapperMesg#(Bool,DemapperInDataSz,RXFPIPrec,RXFPFPrec)) 
      inFromPreDemapper;
   interface Get#(DemapperMesg#(RXGlobalCtrl,DemapperInDataSz,RXFPIPrec,RXFPFPrec))   
      outToPreDescrambler;
   interface Put#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,ViterbiOutput))    
      inFromPreDescrambler;
   interface Get#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) 
      outToDescrambler;
   interface Put#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz))                
      inFromDescrambler;
   interface Get#(RXVector) outRXVector;
   interface Get#(Bit#(8))  outData;
   `ifdef SOFT_PHY_HINTS
   interface Get#(Bit#(8))  outSoftPhyHints;
   `endif
   interface Get#(RXExternalFeedback) packetFeedback;
   method    Put#(Bit#(0)) abortReq;
   interface Get#(Bit#(0)) abortAck;
endinterface
      
typedef enum{
   RX_IDLE = 0,     // idle
   RX_HEADER = 1,   // decoding header
   RX_HTAIL = 2,    // sending zeros after header
   RX_FEEDBACK = 3, // waiting for feedback
   RX_DATA = 4,     // decoding data
   RX_DTAIL = 5     // sending zeros after data
} RXCtrlState deriving(Eq,Bits);

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkPreDemapperRXController(PreDemapperRXController);

   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXState = CRAddr{a: fromInteger(valueof(AddrRXState)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSuppressedLongSyncs = CRAddr{a: fromInteger(valueof(AddrSuppressedLongSyncs)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrAcceptedLongSyncs = CRAddr{a: fromInteger(valueof(AddrAcceptedLongSyncs)) , o: 0};

   // state elements
   FIFO#(DemapperMesg#(RXGlobalCtrl,DemapperInDataSz,RXFPIPrec,RXFPFPrec)) outQ <- mkLFIFO;
   Reg#(RXCtrlState) rxState <- mkCBRegR(addrRXState,RX_IDLE); // the current state
   FIFO#(RXExternalFeedback) outFeedbackFIFO <- mkFIFO;
   FIFO#(Bit#(0))    abortAckQ <- mkFIFO;
   Reg#(Bit#(32))    suppressedLongSyncs <- mkCBRegR(addrSuppressedLongSyncs,0);
   Reg#(Bit#(32))    acceptedLongSyncs <- mkCBRegR(addrAcceptedLongSyncs,0);
//   Reg#(Bit#(3))     zeroCount <- mkRegU;       // count no of zeros symbol sent
   Reg#(Rate)        rxRate <- mkRegU;          // the packet rate for receiving
   Reg#(Bit#(17))    rxLength <- mkReg(0);        // the remaining of data to be received (in terms of bits)
   Reg#(Bool)        abortReg <- mkReg(False);
   
   // constants
   // data bis per ofdm symbol half channel only
   Bit#(17) dbps = fromInteger(bitsPerSymbol(rxRate));    
   
   // send a fake header worth of data down the pipeline during abort 
   rule abortSendFakeHeader(rxState == RX_HTAIL && rxLength > 0 && abortReg);
      RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: False,
                                         updatePilot: True,
                                         viterbiPushZeros: False,
                                         rate: R0};
      outQ.enq(DemapperMesg{control:rxCtrl, data: ?});
      if (rxLength <= fromInteger(bitsPerSymbol(R0)))
         begin
            rxLength <= 0;
         end
      else
         begin
            rxLength <= rxLength - fromInteger(bitsPerSymbol(R0));
         end
   endrule

   // send 1 extra symbol of zeros to push out data from vitebri (also reset the viterbi state)
   rule sendZeros((rxState == RX_HTAIL && rxLength == 0) || rxState == RX_DTAIL);
      RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: False,
                                         updatePilot: False,
                                         viterbiPushZeros: True,
					 rate: R0};
      Symbol#(DemapperInDataSz,RXFPIPrec,RXFPFPrec) zeroSymbol = replicate(cmplx(0,0));
      outQ.enq(DemapperMesg{control:rxCtrl, data: zeroSymbol});
      rxState <= (rxState == RX_HTAIL) ? RX_FEEDBACK : RX_IDLE;
      if (`DEBUG_RXCTRL == 1)
         $display("PreDemapperRXCtrllr sendZeros rxState:%d rxLength:%d",rxState,rxLength);
   endrule 

   // interface methods
   // We want to make sure that only one first symbol is sent per packet.
   interface Put inFromPreDemapper;
      method Action put(DemapperMesg#(Bool,DemapperInDataSz,RXFPIPrec,RXFPFPrec) mesg) 
	 if ((rxState != RX_HTAIL || rxLength > 0) && rxState != RX_DTAIL && rxState != RX_FEEDBACK
             && !abortReg);
	 case (rxState)
	    RX_IDLE: 
	    begin
	       if (mesg.control) // only process if it is a new packet, otherwise, drop it
		  begin	
                     acceptedLongSyncs <= acceptedLongSyncs + 1;               
                     outFeedbackFIFO.enq(LongSync);
		     RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: True,
                                                        updatePilot: True,
                                                        viterbiPushZeros: False,
							rate: R0};
		     outQ.enq(DemapperMesg{control:rxCtrl, data: mesg.data});
                     rxState <= RX_HTAIL;
                     rxLength <= fromInteger(valueOf(HeaderSz)) - fromInteger(bitsPerSymbol(R0));
		  end  
	       end
	    RX_DATA:
	    begin
               let is_last = rxLength <= dbps;
               let external_feedback = is_last ? DataComplete : HeaderDecoded; 
               if (mesg.control) // only process if it is a new packet, otherwise, drop it
		 begin	
                   suppressedLongSyncs <= suppressedLongSyncs + 1;               
                 end
	       RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: False,
                                                  updatePilot: True,
                                                  viterbiPushZeros: False,
						  rate: rxRate};
	       outQ.enq(DemapperMesg{control:rxCtrl, data: mesg.data});
	       if (is_last) // last symbol
		  begin
                     // Mail out end of data here
		     rxState <= RX_DTAIL;
                     rxLength <= 0;
		  end
	       else
		  begin
		     rxLength <= rxLength - dbps;
		  end
               if (mesg.control || is_last) // if suppressedLongSyncs, should switch back to normal data
                  begin
                     outFeedbackFIFO.enq(external_feedback);
                  end
	    end
            RX_HTAIL: // rxLength > 0
            begin
	       RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: False,
                                                  updatePilot: True,
                                                  viterbiPushZeros: False,
	                                          rate: R0};
	       outQ.enq(DemapperMesg{control:rxCtrl, data: mesg.data});
               if (rxLength <= fromInteger(bitsPerSymbol(R0)))
                  begin
                     rxLength <= 0;
                  end
               else
                  begin
                     rxLength <= rxLength - fromInteger(bitsPerSymbol(R0));
                  end
            end
	 endcase
         if (`DEBUG_RXCTRL == 1)
	    $display("PreDemapperRXCtrllr inFromPreDemapper newPacket: %d rxState:%d rxLength:%d",mesg.control,rxState,rxLength);
      endmethod
   endinterface
 
   interface Put inFeedback;
      method Action put(Feedback#(RXVector,RXVectorDecodeError) feedback) if (rxState == RX_FEEDBACK);
	 let packetInfo = getDataFromFeedback(?,feedback);
         if (abortReg) // finish abortion, send abort ack
            begin
               abortAckQ.enq(?);
               abortReg <= False;
            end
	 if (validFeedback(feedback) && !packetInfo.is_trailer && !abortReg) // set the packet parameter, ignore trailer
	    begin
	       rxState <= RX_DATA;
	       rxRate  <= packetInfo.header.rate; 
	       rxLength <= getBitLength(packetInfo.header.length); // no of bits to be received = (16+8*length+6)
               if (`DEBUG_RXCTRL == 1)
                  begin
                     Bit#(TAdd#(4,SizeOf#(PhyPacketLength))) rxLengthByte = (((zeroExtend(packetInfo.header.length) + 2) << 3) + 6);
	             $display("PreDemapperRXCtrllr valid inFeedback rxState:%d rxLength:%d",rxState,rxLengthByte);
                  end
	    end
	 else // error in decoding package, return to idle, or is trailer
	    begin
               // received abort.  we should notify the agc at this time.
	       rxState <= RX_IDLE; 
               if (`DEBUG_RXCTRL == 1)
	          $display("PreDemapperRXCtrllr abort inFeedback rxState:%d",rxState);
	    end
      endmethod
   endinterface

   interface outToPreDescrambler = fifoToGet(outQ);
   interface outFeedback = fifoToGet(outFeedbackFIFO);
   interface abortAck = fifoToGet(abortAckQ);
      
   method Action abortReq;
      abortReg <= True;
      if (rxState != RX_FEEDBACK || rxState != RX_HTAIL) // abort mechanism = send a fake header and wait for the feedback
         begin
	    RXGlobalCtrl rxCtrl = RXGlobalCtrl{firstSymbol: True,
                                               updatePilot: True,
                                               viterbiPushZeros: False,
	                                       rate: R0};
	    outQ.enq(DemapperMesg{control:rxCtrl, data: ?});
            rxState <= RX_HTAIL;
            rxLength <= fromInteger(valueOf(HeaderSz)) - fromInteger(bitsPerSymbol(R0));
         end
   endmethod 
   
endmodule

(* synthesize *)
module mkPreDescramblerRXController(PreDescramblerRXController);
   // state elements
   FIFO#(DecoderMesg#(RXGlobalCtrl,ViterbiOutDataSz,ViterbiOutput)) inMesgQ <- mkLFIFO;
   FIFO#(DescramblerMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) outMesgQ <- mkLFIFO;
   FIFO#(Feedback#(RXVector,RXVectorDecodeError)) outFeedbackQ <- mkLFIFO;
   FIFO#(RXVector)         outRXVectorQ <- mkLFIFO;
   StreamFIFO#(HeaderSz,TLog#(HeaderSz),Bit#(1)) streamQ <- mkStreamLFIFO;
   Reg#(RXCtrlState)         rxState <- mkReg(RX_IDLE);
//   Reg#(Bit#(3))           zeroCount <- mkReg(0);
   Reg#(Bool)                isGetSeed <- mkReg(False);
   Reg#(Maybe#(Bit#(ScramblerShifterSz))) seed <- mkReg(tagged Invalid);
   Reg#(Bit#(17))            dropData <- mkRegU;
   Reg#(Bit#(17))            checkData <- mkRegU;
   Reg#(PhyPacketLength)     rxLength <- mkRegU; 
   Reg#(Bit#(32))            cycleCount <- mkReg(0);
   Reg#(Bool)                abortReg <- mkReg(False);

   `ifdef SOFT_PHY_HINTS
   Reg#(Bit#(8))             minSoftPhyHints <- mkReg(maxBound);
   FIFO#(Bit#(8))            outSoftPhyHintsQ <- mkLFIFO;
   `endif
   
   // constants
   Bit#(TLog#(HeaderSz)) vOutSz   = fromInteger(valueOf(ViterbiOutDataSz));
   Bit#(TLog#(HeaderSz)) dInSz    = fromInteger(valueOf(DescramblerDataSz));
   Bit#(TLog#(HeaderSz)) headerSz = fromInteger(valueOf(HeaderSz));
   let streamQ_usage = streamQ.usage;
   let streamQ_free  = streamQ.free;

   function Bit#(a) pickSmaller (Bit#(a) x, Bit#(a) y);
      return (x < y) ? x : y;
   endfunction
      
   // rules
   rule tickClock(True);
      cycleCount <= cycleCount + 1;
   endrule
   
   rule decodingHeader(rxState == RX_HEADER && streamQ_usage >= headerSz);
      let header       = pack(streamQ.first);
      let rx_feedback  = decodeHeader(header);
      let rx_vec       = getDataFromFeedback(?,rx_feedback);
      let rx_err       = getErrorFromFeedback(?,rx_feedback);
      outFeedbackQ.enq(rx_feedback); 
      streamQ.deq(headerSz);
      rxState <= RX_HTAIL;
      dropData <= fromInteger(bitsPerSymbol(R0));
      
      if (abortReg) // abort
         begin
            isGetSeed <= False;
         end
      else
         begin
            if (validFeedback(rx_feedback))
	       begin
	          outRXVectorQ.enq(rx_vec);
                  if (!rx_vec.is_trailer) // data only follow header not trailer
                     begin
	                isGetSeed <= True;
	                rxLength  <= rx_vec.header.length; // no of bits remained in the packet
                     end
                  else
                     begin
                        abortReg <= True; // don't go to RX_DATA mode
                     end
                  if (`DEBUG_RXCTRL == 1)
                     $display("PreDescramblerRXCtrllr header: %b rate: %b length: %d is_trailer: %d", header, rx_vec.header.rate, rx_vec.header.length, rx_vec.is_trailer);
	       end
            else
               begin
                  abortReg <= True; // don't go to RX_DATA mode
                  if (`DEBUG_RXCTRL == 1)
                     $display("PreDescramblerRXCtrllr header (%b) decode error: %d (0 = ParityError, 1 = RateError, 2 = ZeroFieldError)",header,rx_err);
               end
         end
   endrule
      
   rule getSeed(rxState == RX_DATA && isGetSeed && streamQ_usage >= fromInteger(valueOf(PreDataSz)));
      Bit#(PreDataSz) predata = truncate(pack(streamQ.first)); 
      // Use the hard-coded decoder seed instead of the one from the stream
      // to reduce bit-errors
      if (`MAGIC_DESCRAMBLE_SEED == 1)
         seed <= tagged Valid magicConstantDecoderSeed;
      else
         seed <= tagged Valid getSeedFromPreData(predata);
      isGetSeed <= False;
      streamQ.deq(fromInteger(valueOf(PreDataSz)));
      if (`DEBUG_RXCTRL == 1)
         $display("PreDescramblerRXCtrllr getSeed rxState:%d rxLength:%d, seed: %b,  streamQ: %b",rxState,rxLength,getSeedFromPreData(predata), streamQ.first);      
   endrule
   
   rule sendData(rxState == RX_DATA && !isGetSeed && streamQ_usage >= dInSz);
      let rxDCtrl = RXDescramblerCtrl{seed: seed, bypass: 0}; // descrambler ctrl, no bypass
      let rxGCtrl = RXGlobalCtrl{firstSymbol: isValid(seed), updatePilot: ?, viterbiPushZeros:?,rate: ?};
      let rxCtrl = RXDescramblerAndGlobalCtrl{descramblerCtrl: rxDCtrl, length: rxLength, globalCtrl: rxGCtrl};
      seed <= tagged Invalid;
      outMesgQ.enq(DescramblerMesg{control: rxCtrl, data: pack(take(streamQ.first))});
      if (dropData <= zeroExtend(dInSz)) // last data
         begin
            dropData <= 0;
            rxState <= RX_IDLE;
            streamQ.clear();
         end
      else
         begin
            dropData <= dropData - zeroExtend(vOutSz);
            streamQ.deq(dInSz);
         end
      if (`DEBUG_RXCTRL == 1)
         $display("PreDescramblerRXCtrllr sendData rxState:%d rxLength:%d, streamQ: %b",rxState,rxLength,streamQ.first);
   endrule
   
   rule processInMesgQ(streamQ_free >= vOutSz);
      let mesg = inMesgQ.first;
      `ifdef SOFT_PHY_HINTS
      let softHints = tpl_2(unzip(mesg.data));
      let msgData = tpl_1(unzip(mesg.data));
      `else
      let msgData = mesg.data;
      `endif
      case (rxState)
         RX_IDLE: begin
                     inMesgQ.deq();
                     if (mesg.control.firstSymbol) // only process if start of packet
                        begin
                           `ifdef SOFT_PHY_HINTS
                           minSoftPhyHints <= maxBound;
                           `endif
                           rxState <= RX_HEADER;
                           dropData <= zeroExtend(headerSz) - zeroExtend(vOutSz);
		           streamQ.enq(vOutSz,append(msgData,replicate(0)));
                        end
                  end
         RX_HEADER: begin
                       if (dropData > 0) // send the remaining header
                          begin
                             inMesgQ.deq();
                             dropData <= dropData - zeroExtend(vOutSz);
		             streamQ.enq(vOutSz,append(msgData,replicate(0)));
                          end
                    end
         RX_HTAIL: begin
                      inMesgQ.deq();
                      if (dropData == zeroExtend(vOutSz)) // last one (should make sure it always align)
                         begin
                            if (abortReg)
                               begin
                                  abortReg <= False;
                                  rxState <= RX_IDLE;
                                  dropData <= 0;
                               end
                            else
                               begin
                                  rxState <= RX_DATA;
                                  dropData <= zeroExtend(rxLength) << 3;
                                  `ifdef SOFT_PHY_HINTS
                                  checkData <= getBitLength(rxLength) - fromInteger(valueOf(PostDataSz));
                                  `endif
                               end
                         end
                      else
                         begin
                            dropData <= dropData - zeroExtend(vOutSz);
                         end
                      if (`DEBUG_RXCTRL == 1)
                         $display("PreDescramblerRXCtrllr rxState:%d dropData:%d @ %d",rxState,dropData,cycleCount); // skip zeros tell zeros skipped
                   end
         RX_DATA: begin
                     inMesgQ.deq();
                     streamQ.enq(vOutSz,append(msgData,replicate(0)));
                     `ifdef SOFT_PHY_HINTS
                     Bit#(8) minHints = fold(pickSmaller, map(truncate, softHints));
                     let newMinSoftPhyHints = (minHints < minSoftPhyHints) ? minHints : minSoftPhyHints; 
                     minSoftPhyHints <= newMinSoftPhyHints;
                     if (`DEBUG_RXCTRL == 1)
                        begin
                           for (Integer i = 0; i < valueOf(ViterbiOutDataSz); i = i + 1)
                              $display("PreDescramblerRXCtrllr softphy hints: %d",softHints[i]);
                        end
                     if (checkData > 0)
                        begin
                           if (checkData <= zeroExtend(vOutSz)) // last data
                              begin
                                 checkData <= 0;
//                                 outSoftPhyHintsQ.enq(newMinSoftPhyHints);
                                 if (`DEBUG_RXCTRL == 1)
                                    $display("PreDescramblerRXCtrllr report min softphy hint of the packet %d",newMinSoftPhyHints);
                              end
                           else
                              begin
                                 checkData <= checkData - zeroExtend(vOutSz);
                              end
                        end
                     `endif
                  end
      endcase
      if (`DEBUG_RXCTRL == 1)
         $display("PreDescramblerRXCtrll processInMsgQ rxState:%d rxLength:%d",rxState,rxLength);      
   endrule
   

   // interface methods
   interface inFromPreDescrambler = fifoToPut(inMesgQ);     
   interface outToDescrambler = fifoToGet(outMesgQ);   
   interface outRXVector = fifoToGet(outRXVectorQ);   
   interface outFeedback = fifoToGet(outFeedbackQ);
   `ifdef SOFT_PHY_HINTS
   interface outSoftPhyHints = fifoToGet(outSoftPhyHintsQ);
   `endif
      
   method Action abortReq;
      abortReg <= True;
      rxState <= RX_IDLE;
      streamQ.clear();
   endmethod
     
endmodule 

(* synthesize *)
module mkPostDescramblerRXController(PostDescramblerRXController);
   // state elements
   FIFO#(EncoderMesg#(RXDescramblerAndGlobalCtrl,DescramblerDataSz)) inMesgQ <- mkLFIFO;
   FIFO#(Bit#(8)) outDataQ <- mkSizedFIFO(100);
   StreamFIFO#(24,5,Bit#(1)) streamQ <- mkStreamLFIFO; // descramblerdatasz must be factor of 12
   Reg#(PhyPacketLength)     rxLength <- mkReg(0); // no of bytes remains to be received
   Reg#(Bit#(32))            cycleCount <- mkReg(0); 
   
   // constants
   Bit#(5) dInSz = fromInteger(valueOf(DescramblerDataSz));
   let streamQ_usage = streamQ.usage;
   let streamQ_free  = streamQ.free;
   
   // rules
   rule tickClock(True);
      cycleCount <= cycleCount + 1;
   endrule
   
   rule processInMesgQ(streamQ_free >= dInSz);
      let mesg = inMesgQ.first;
      if (mesg.control.globalCtrl.firstSymbol)
         begin
            if (rxLength == 0 && streamQ_usage == 0)
               begin
                  rxLength <= mesg.control.length;
               end
         end
//       else         
//          begin 
// 	    streamQ.enq(dInSz,append(unpack(mesg.data),replicate(0)));
//             inMesgQ.deq();
//          end              
      streamQ.enq(dInSz,append(unpack(mesg.data),replicate(0)));
      inMesgQ.deq();
      if (`DEBUG_RXCTRL == 1)
         $display("PostDescramblerRXCtrllr processInMesgQ rxLength:%d mesg.control.length %d",rxLength,mesg.control.length);      
   endrule
   
   // Seems like a reasonable place to detect end of packet
   rule clearStreamQ(rxLength == 0 && streamQ_usage > 0); // remove junk data
      streamQ.clear();
      if (`DEBUG_RXCTRL == 1)
         $display("PostDescramblerRXCtrllr clearStreamQ streamQ_usage: %d",streamQ_usage);      
   endrule
      
   // Take data bits from stream, package into output byte
   rule deqStreamQ(rxLength > 0 && streamQ_usage >= 8);
     Bit#(8) outData = truncate(pack(streamQ.first));
     streamQ.deq(8);
     outDataQ.enq(outData);
     rxLength <= rxLength - 1;
      if (`DEBUG_RXCTRL == 1)
         $display("PostDescramblerRXCtrllr deqStreamQ data:%h streamQ_usage: %d rxLength: %d @ %d",outData,streamQ_usage,rxLength-1,cycleCount);      
   endrule
   
   // interface methods
   interface inFromDescrambler = fifoToPut(inMesgQ);
   interface outData = fifoToGet(outDataQ);
      
   method Action abortReq;
      outDataQ.clear();
      rxLength <= 0; // no matter what state it is at, reset it the waiting message count to 0, any remaining data should be cleared until the next valid message
      if (`DEBUG_RXCTRL == 1)
         $display("PostDecramblerRXCtrllr abortReq");
   endmethod
      
endmodule

//(* synthesize *)
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkRXController(RXController);
   // state elements
   let preDemapperCtrllr     <- mkPreDemapperRXController;
   let preDescramblerCtrllr  <- mkPreDescramblerRXController;
   let postDescramblerCtrllr <- mkPostDescramblerRXController;
   let feedbackFIFO <- mkFIFOF;   

   rule checkFIFO(!feedbackFIFO.notFull);
      if (`DEBUG_RXCTRL == 1)
         $display("RXControl: feedbackFIFO is full"); 
   endrule

   // We must tap out this feedback to other modules to control agc and ghold
   rule headerFeedback;
      let feedback <- preDescramblerCtrllr.outFeedback.get;
      let packetInfo = getDataFromFeedback(?,feedback);
      preDemapperCtrllr.inFeedback.put(feedback);
      if(validFeedback(feedback))
         begin
            let gct_feedback = packetInfo.is_trailer ? DataComplete : HeaderDecoded; // back to idle if trailer 
            feedbackFIFO.enq(gct_feedback);
         end
      else
         begin
            feedbackFIFO.enq(Abort);
         end
   endrule
 
   rule dataFeeback;
     let feedback <- preDemapperCtrllr.outFeedback.get;
     feedbackFIFO.enq(feedback);
   endrule

   
   // methods
   interface inFromPreDemapper = preDemapperCtrllr.inFromPreDemapper;
   interface outToPreDescrambler = preDemapperCtrllr.outToPreDescrambler;
   interface inFromPreDescrambler = preDescramblerCtrllr.inFromPreDescrambler;
   interface outToDescrambler = preDescramblerCtrllr.outToDescrambler;
   interface inFromDescrambler = postDescramblerCtrllr.inFromDescrambler;
   interface outRXVector = preDescramblerCtrllr.outRXVector;
   interface outData   = postDescramblerCtrllr.outData;
   `ifdef SOFT_PHY_HINTS
   interface outSoftPhyHints = preDescramblerCtrllr.outSoftPhyHints;
   `endif
   interface packetFeedback = fifoToGet(fifofToFifo(feedbackFIFO));
   interface abortAck = preDemapperCtrllr.abortAck;

   interface Put abortReq;
      method Action put(Bit#(0) dont_care);
         preDemapperCtrllr.abortReq;
         preDescramblerCtrllr.abortReq;
         postDescramblerCtrllr.abortReq;
      endmethod
   endinterface
 
endmodule

