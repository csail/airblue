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

import Controls::*;
import Complex::*;
import CORDIC::*;
import DataTypes::*;
import FIFO::*;
import FIFOF::*;
import FixedPoint::*;
import FixedPointLibrary::*;
import Interfaces::*;
import Preambles::*;
import ShiftRegs::*;
import SParams::*;
import SynchronizerLibrary::*;
import Vector::*;
import FPComplex::*;
import GetPut::*;
import ProtocolParameters::*;
import FPGAParameters::*;
import RWire::*;
import Register::*;
import StreamCaptureFIFO::*;
import CBus::*;
import CBusUtils::*;

//`define debug_mode True // uncomment this line for displaying text
`define coarCorrPowThreshold         unpack(16384) // coarse power square threshold to trigger auto-correlation (remove small DC offset)
`define coarPowSqPlateauThreshold    3             // this threshold indicate the consecutive short symbol power square should not differ more than 1/2^(this_value)*(last_power_sq) 
`define instantiateStreamCaptureFIFO True          // instantiate stream fifo to collect SNR?

typedef struct{
  ctrlT   control;  // estimate postion
  data1T  data1;     // data1
  data2T  data2;     // data2
} SyncData#(type ctrlT, type data1T, type data2T) deriving (Bits, Eq);

typedef enum{
   Dump = 0,           // useless data, don't output
   Idle = 1,           // don't do estimation
   Collect = 2,        // collect correlation and calculate moving average
   ShortSync = 3,      // make coarse estimation
   GainStart = 4,      // for AGC only, start adjustment
   GHoldStart = 5,     // for AGC only, start ghold
   LongSync = 6,       // make fine estimation
   TimeOut = 7         // timeout reset
} ControlType deriving (Bits, Eq);

typedef enum{
  SNormal = 0,
  STrans = 1,
  LNormal = 2,
  LTrans = 3
} TimeState deriving (Bits, Eq);

// type definitions for the input of timing and frequency synchronizer

// defintion of FineTimeInT
typedef struct{
   ControlType                           control;     // control
   FPComplex#(SyncIntPrec,SyncFractPrec) delayedData; // delayed input (loop around once already) 
} FineTimeInT deriving (Bits, Eq);

// definition of FreqEstInT
typedef struct{
   ControlType                            control;         // control
   FPComplex#(SyncIntPrec,SyncFractPrec)  data;            // original input
   FPComplex#(SyncIntPrec,SyncFractPrec)  delayedData;     // delayed input (loop around once already) 
   FPComplex#(CorrIntPrec, SyncFractPrec) autoCorrelation; // auto correlation result
} FreqEstInT deriving (Bits, Eq);

// definition of FreqEstInT
typedef struct{
   ControlType                             control;         // control
   FPComplex#(SyncIntPrec,SyncFractPrec)   data;            // original input
   FPComplex#(SyncIntPrec,SyncFractPrec)   delayedData;     // delayed input (loop around once already) 
   FixedPoint#(SyncIntPrec, SyncFractPrec) angle;           // angle to be rotated 
} FreqRotInT deriving (Bits, Eq);

// defintion of FineTimeInT
typedef struct{
   ControlType                           control;     // control
   FPComplex#(SyncIntPrec,SyncFractPrec) delayedData; // delayed input (loop around once already) 
   FPComplex#(SyncIntPrec,SyncFractPrec) outData;     // data that output to the next module
} FreqRotOutT deriving (Bits, Eq);

typedef FixedPoint#(CoarTimeAccumIntPrec,SyncFractPrec) CoarPowType; 

// typedef struct{
//    ControlType                                      control; // control
//    FixedPoint#(CoarTimeAccumIntPrec,SyncFractPrec)  coarPow; // coarse power moving average
// } GainCtrlInT deriving (Bits, Eq);   

// an accumulator that accumulate a moving windows of sample
interface Accumulator#(numeric type length, type a, type b); // accumulate the last length items of type a (output is type b)
   method ActionValue#(b) getNextVal(a nextInput);           // add the next value to the accumulator and get the result
   method Action          clear();                           // reset the accumulator
endinterface

interface AutoCorrelator;
   // inputs
   method Action putInput(FPComplex#(SyncIntPrec,SyncFractPrec) x);
   method Action setMode(Bool isShortMode);

   // outputs
   method ActionValue#(CorrType) getCorrelation();
endinterface

// timing synchronizer interface (used for both coarse and fine estimations)
interface TimeEstimator;
   // inputs
   method Action putCoarTimeIn(FPComplex#(SyncIntPrec,SyncFractPrec) coarTimeIn);
   method Action putFineTimeIn(FineTimeInT fineTimeIn);

   // output
   method ActionValue#(FreqEstInT)  getFreqEstIn();
   interface ReadOnly#(CoarPowType) readCoarPow; 
endinterface

// carrier frequency offset estimator (used for both coarse and fine estimations) 
interface FreqEstimator;
   // inputs
   method Action putFreqEstIn(FreqEstInT freqEstIn);

   // output
   method ActionValue#(FreqRotInT) getFreqRotIn();
endinterface

// carrier frequency offset compensator
interface FreqRotator;
   // inputs
   method Action putFreqRotIn(FreqRotInT freqRotIn);

   // output
   method ActionValue#(FreqRotOutT) getFreqRotOut();
endinterface

// implementation of an accumulator
module mkAccumulator#(function b extend(a i)) (Accumulator#(length,a,b))
   provisos (Arith#(b),
             Bits#(a,a_sz),
             Bits#(b,b_sz));

   RWire#(Tuple2#(a,b)) accumW   <- mkRWire();
   PulseWire            clearW   <- mkPulseWire();      
   Reg#(b)              accum    <- mkReg(unpack(0));
   ShiftRegs#(length,a) delaySub <- mkCirShiftRegsNoGetVec();

   rule updateState(True);
      if (clearW)
         begin
            accum <= unpack(0);
            delaySub.clear();
         end
      else
         if (isValid(accumW.wget()))
            begin
               accum <= tpl_2(validValue(accumW.wget()));
               delaySub.enq(tpl_1(validValue(accumW.wget())));
            end
   endrule                        
   
   method ActionValue#(b) getNextVal(a nextInput);
      let newAccum = accum + extend(nextInput) - extend(delaySub.first()); 
      accumW.wset(tuple2(nextInput,newAccum));
      return newAccum;
   endmethod
   
   method Action clear();
      clearW.send();
   endmethod
endmodule

(* synthesize *)
module mkAutoCorrelator(AutoCorrelator);

   // output buffer
   FIFO#(CorrType) outQ <- mkSizedFIFO(2);

   // delay queues
   ShiftRegs#(SSLen, FPComplex#(SyncIntPrec,SyncFractPrec))             delayIn <- mkAutoCorr_DelayIn;
   ShiftRegs#(SSLen, FPComplex#(MulIntPrec,SyncFractPrec))              corrSub <- mkAutoCorr_CorrSub;
   
   ShiftRegs#(LSLSSLen, FPComplex#(SyncIntPrec,SyncFractPrec))          extDelayIn <- mkAutoCorr_ExtDelayIn;
   ShiftRegs#(LSLSSLen, FPComplex#(MulIntPrec,SyncFractPrec))           extCorrSub <- mkAutoCorr_ExtCorrSub;

   // accumulator
   Reg#(CorrType)                                          corr <- mkReg(cmplx(0,0));

   // mode
   Reg#(Bool) 						   isShort <- mkReg(True); 						   
   `ifdef debug_mode
   Reg#(Bit#(64)) cycle <- mkReg(0);
   
   rule tick(True);
      cycle <= cycle + 1;
   endrule
   `endif
   
   method Action putInput(FPComplex#(SyncIntPrec,SyncFractPrec) x);
   begin
      let conjDelayIn = cmplxConj(delayIn.first); // conjugate of delayed input
      let curIn = x;
      FPComplex#(MulIntPrec,SyncFractPrec) corrAdd = fpcmplxTruncate(fpcmplxMult(curIn,conjDelayIn)); 
      let newCorr = corr + 
		    fpcmplxSignExtend(corrAdd) - 
		    fpcmplxSignExtend(corrSub.first);
      corr <= newCorr;
      outQ.enq(newCorr);

      `ifdef debug_mode
         $write("AutoCorr.input:");
         cmplxWrite("("," + ","i)",fxptWrite(7),x);
         $display("");
      `endif
      if (isShort)
	begin
	   delayIn.enq(curIn);
	   corrSub.enq(corrAdd);
	   `ifdef debug_mode
	   $display("RULE at cycle %d AutoCorr.putInput: isShort",cycle);
	   `endif
	end
      else
	begin
	   extDelayIn.enq(curIn);
	   delayIn.enq(extDelayIn.first);
	   extCorrSub.enq(corrAdd);
	   corrSub.enq(extCorrSub.first);
	   `ifdef debug_mode
	   $display("RULE at cycle %d AutoCorr.putInput: isLong",cycle);
	   `endif
	end // else: !if(isShort)
   end
   endmethod

   method Action setMode(Bool isShortMode);
   begin
      // reset accumulator and shiftregs
      delayIn.clear;
      corrSub.clear;
      extDelayIn.clear;
      extCorrSub.clear;
      corr <= cmplx(0,0);
      isShort <= isShortMode;
      `ifdef debug_mode
      $display("METHOD at cycle %d AutoCorr.setMode: %d",cycle,isShortMode);
      `endif
   end
   endmethod

   method ActionValue#(CorrType) getCorrelation();
   begin
      outQ.deq;
      `ifdef debug_mode
      $write("METHOD at cycle %d AutoCorr.getCorrelation:",cycle);
      cmplxWrite("("," + ","i)",fxptWrite(7),outQ.first);
      $display("");
      `endif
      return outQ.first;
   end
   endmethod
     
endmodule

//(* synthesize *)
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkTimeEstimator(TimeEstimator);
   // constants
   Integer lSStart = valueOf(LSStart); // starting position of long preamble
   Integer signalStart = valueOf(SignalStart); // starting position of the first data symbol
   Integer lSyncPos = valueOf(LSyncPos); // synchronization position of long preamble
   Integer freqMeanLen = valueOf(FreqMeanLen); // no. samples collected for freq estimation
   Integer coarTimeCorrPos = valueOf(CoarTimeCorrPos); // first pos that can detect high correlation
   Integer coarResetPos = valueOf(TimeResetPos); // timeout period, must be bigger than SignalStart 
   Integer coarTimeAccumDelaySz = valueOf(CoarTimeAccumDelaySz);
   
   let fullLongPreambles = insertCP0(getLongPreambles);
   Vector#(FineTimeCorrSz, FineTimeType) longPreambles = map(fpcmplxTruncate,take(fullLongPreambles));
   let maxFineTimePowSq = fpcmplxModSq(crossCorrelation(longPreambles,longPreambles)) >> 2; 
      
   // states
   `ifdef instantiateStreamCaptureFIFO

   Reg#(Bit#(32))   coarCorrPowReg        <- mkRegU;
   Reg#(Bit#(32))   coarPowSqReg          <- mkRegU;

   RWire#(Bit#(32)) coarCorrPowRwire      <- mkRWire;
   RWire#(Bit#(32)) coarPowSqRwire        <- mkRWire;
   
   FIFOF#(Bit#(32)) coarCorrPowStreamfifo <- mkStreamCaptureFIFOF(1024);
   FIFOF#(Bit#(32)) coarPowSqStreamfifo   <- mkStreamCaptureFIFOF(1024);

   mkCBusGet(valueof(AddrCoarCorrPowStreamFifoOffset),fifoToGet(fifofToFifo(coarCorrPowStreamfifo)));
   mkCBusGet(valueof(AddrCoarPowSqStreamFifoOffset),fifoToGet(fifofToFifo(coarPowSqStreamfifo)));

   `endif
   
   // autocorrelator
   AutoCorrelator          autoCorr <- mkAutoCorrelator;
   
   // dummy autocorrelator need to match the latency of autoCorr
   FIFOF#(FreqEstInT)      autoQ <- mkSizedFIFOF(2);

   // input buffers
   FIFOF#(FPComplex#(SyncIntPrec,SyncFractPrec)) coarTimeInQ <- mkSizedFIFOF(2); // the buffer should be large enough (> whole latency of synchronizer)
   FIFOF#(FPComplex#(SyncIntPrec,SyncFractPrec)) coarInPipeQ <- mkSizedFIFOF(2); 
   FIFOF#(FixedPoint#(CoarTimeAccumIntPrec,SyncFractPrec)) coarPowQ <- mkSizedFIFOF(2); // buffer the coarPow 
 
   FIFOF#(FineTimeInT)     fineTimeInQ <- mkSizedFIFOF(3);                     
   FIFOF#(FPComplex#(SyncIntPrec,SyncFractPrec)) fineInPipeQ <- mkSizedFIFOF(2);
   FIFOF#(FineTimeCorrType)              fineTimeCorrQ <- mkSizedFIFOF(2); // buffer the fine time correlation result 

   FIFOF#(TimeState) timeStatePipeQ <- mkSizedFIFOF(2); // buffer the command
   
   // output buffer
   FIFOF#(FreqEstInT) outQ <- mkSizedFIFOF(2);

   // delay queues
   ShiftRegs#(FineTimeCorrDelaySz, FPComplex#(1,7)) fineDelay <- mkTimeEst_FineDelay;

   //accumulators
   // accumulator for power of the last SSLen input 
   Accumulator#(SSLen, 
                FixedPoint#(MulIntPrec,SyncFractPrec),
                FixedPoint#(CoarTimeAccumIntPrec,SyncFractPrec)) coarPowAccum  <- mkAccumulator(fxptZeroExtend);
   // accumulator for the last CoarTimeAccumDelaySz coarse time detection
   Accumulator#(CoarTimeAccumDelaySz, 
                Bit#(1),
                Bit#(CoarTimeAccumIdx))                          coarTime <- mkAccumulator(zeroExtend);
   
   //other regs
   Reg#(FixedPoint#(CoarTimeAccumIntPrec,SyncFractPrec))   coarPow <- mkReg(0);
   Reg#(FixedPoint#(CoarTimeCorrIntPrec,CoarTimeCorrFractPrec)) coarPowSq <- mkReg(0);
   Reg#(Bit#(CounterSz))                                   coarPos <- mkReg(0);     // current most likely short preamble position
   Reg#(Bool) 	                                           coarDet <- mkReg(False); // short preamble is detected
   
   Reg#(Bit#(CounterSz))                                   finePos <- mkReg(0);     // current most likely long preamble position
   Reg#(Bool) 					           fineDet <- mkReg(False); // long preamble is detected
   Reg#(FineTimeCorrPowType)                               fineMaxCorrPow <- mkReg(0); // max detector of long sync
   Reg#(Bit#(CounterSz))                                   fineMaxPos <- mkReg(0);     // detected max position (in terms of coarPos
   
   Reg#(Bool) 						   isProlog <- mkReg(True); // setup at the beginning
   Reg#(TimeState) 					   status  <- mkReg(SNormal); // status for stage 1
   Reg#(TimeState)                                         status2 <- mkReg(LNormal); // statue for stage 2
   
   `ifdef debug_mode
   Reg#(Bit#(64)) cycle <- mkReg(0);
   `endif
   
   rule procProlog(isProlog); // initial setup
      if (fineTimeInQ.notEmpty) // finish
	begin
	   isProlog <= False;
	end
      else // not yet fill up pipeline, keep sending
	begin
	   autoQ.enq(FreqEstInT{control: Dump,
	                        data: ?,
	                        delayedData: ?,
                                autoCorrelation: ?});	   
	end
      `ifdef debug_mode
      $display("RULE at cycle %d TimeEst.procProlog",cycle);
      `endif
   endrule
   
   rule procAutoQToOutQ(True);
      autoQ.deq();
      outQ.enq(autoQ.first());
   endrule

   rule procAutoCorrSN(!isProlog && status == SNormal);
      let curIn = coarTimeInQ.first;
      
      // calculate the accumulated power of the last 16 samples
      FixedPoint#(MulIntPrec,SyncFractPrec) coarPowAdd = fxptTruncate(fpcmplxModSq(curIn));
      let newCoarPow <- coarPowAccum.getNextVal(coarPowAdd);
      coarPow <= newCoarPow;

      coarTimeInQ.deq();
      fineTimeInQ.deq();
      coarInPipeQ.enq(curIn);
      fineInPipeQ.enq(fineTimeInQ.first.delayedData);
      if (fineTimeInQ.first.control == ShortSync)
	begin
	   status <= LNormal;
	   autoCorr.setMode(False);
	   timeStatePipeQ.enq(STrans);
	end
      else
	begin
	   coarPowQ.enq(newCoarPow);
	   autoCorr.putInput(curIn);
	   timeStatePipeQ.enq(SNormal);
	end // else: !if(fineTimeInQ.first.control == ShortSync)
      `ifdef debug_mode
      $display("RULE at cycle %d TimeEst.procAutoCorrSN",cycle);
      `endif
   endrule

   rule  procAutoCorrLN(!isProlog && status == LNormal);
      let curIn = coarTimeInQ.first;
      FineTimeType fineData = fpcmplxTruncate(fineTimeInQ.first.delayedData);
      Vector#(FineTimeCorrSz, FineTimeType) fineTimeCorrIn = append(fineDelay.getVector, 
                                                                    cons(fineData, nil));
      let newFineTimeCorr = crossCorrelation(fineTimeCorrIn, longPreambles);

      // calculate the accumulated power of the last 16 samples
      FixedPoint#(MulIntPrec,SyncFractPrec) coarPowAdd = fxptTruncate(fpcmplxModSq(curIn));
      let newCoarPow <- coarPowAccum.getNextVal(coarPowAdd);
      coarPow <= newCoarPow;
      
      fineDelay.enq(fineData);
      coarTimeInQ.deq();
      fineTimeInQ.deq();
      coarInPipeQ.enq(coarTimeInQ.first);
      fineInPipeQ.enq(fineTimeInQ.first.delayedData);
      if (fineTimeInQ.first.control == LongSync || fineTimeInQ.first.control == TimeOut)
	 begin
            timeStatePipeQ.enq(LTrans);
	    status <= SNormal;
	    autoCorr.setMode(True);
	 end
      else
         begin
            fineTimeCorrQ.enq(newFineTimeCorr);
            timeStatePipeQ.enq(LNormal);
            autoCorr.putInput(fineTimeInQ.first.delayedData);	
         end
      `ifdef debug_mode
      $write("RULE at cycle %d TimeEst.procAutoCorrLN: fineSign: %d + %di,",cycle,fineSign.rel,fineSign.img);
      $write("input: ");
      cmplxWrite("("," + ","i), ",fxptWrite(7),fineTimeInQ.first.delayedData);
      $display("");
      $display("TimeEst.procAutoCorrLN: fineTimeCorrIn:%h, ",fineTimeCorrIn);
      $display("TimeEst.procAutoCorrLN: longPreSigns:%h, ",longPreambles);
      `endif
   endrule

   rule procTimeEstSN(!isProlog && timeStatePipeQ.first == SNormal);
      //variables
      ControlType outControl = Idle;
      Bit#(CounterSz) newCoarPos;
      let newCorr <- autoCorr.getCorrelation;
      let newCoarPow = coarPowQ.first;
      FPComplex#(CoarTimeAccumIntPrec, SyncFractPrec) newCoarCorr = fpcmplxTruncate(newCorr);           
      let newCoarCorrPow = fpcmplxModSq(newCoarCorr);
      FixedPoint#(CoarTimeCorrIntPrec,CoarTimeCorrFractPrec) newCoarPowSq = fxptZeroExtend(fxptMult(newCoarPow,newCoarPow));
      $write("PLOTSHORTSYNC coarCorrPow: ");
      fxptWrite(6,newCoarCorrPow);
      $write(" coarPowSq: ");
      fxptWrite(6,newCoarPowSq);
      $display("");

      if (coarDet)
	begin
	   newCoarPos = coarPos + 1;
	end
      else
	begin
	   let coarTimeAdd    = (newCoarCorrPow > (newCoarPowSq >> 1)) && // big correlation observed
                                (abs(newCoarPowSq - coarPowSq) < 
                                 (coarPowSq >> `coarPowSqPlateauThreshold)) && // make sure they are plateau
                                (newCoarCorrPow > `coarCorrPowThreshold); // ignore small dc offset
//	   let coarTimeAdd    = (newCoarCorrPow > (fxptZeroExtend(newCoarPowSq) >> 1));
	   let newCoarTime   <- coarTime.getNextVal(pack(coarTimeAdd));
//	   newCoarPos         = zeroExtend(newCoarTime) +
//	                        fromInteger(coarTimeCorrPos - 1);
           coarPowSq <= newCoarPowSq; 
	   if (newCoarTime >= fromInteger(coarTimeAccumDelaySz*7/8)) // coar detected
//	   if (newCoarTime == fromInteger(coarTimeAccumDelaySz)) // coar detected
	      begin
		 coarDet <= True;
		 coarTime.clear();  // reset coarTime
                 newCoarPos = fromInteger(valueOf(SSyncPos)); // conservatively assume +8 position 
	      end
           else
              begin
                 newCoarPos = 0;
              end
//           `ifdef debug_mode
           $write("RULE TimeEst.procTimeEstSN: coarTime: %d, coarCorrPow: ",newCoarTime);
           fxptWrite(6,newCoarCorrPow);
           $write(" coarPowSq: ");
           fxptWrite(6,newCoarPowSq);
           $display(" coarTimeAdd: %d",coarTimeAdd);
//           `endif
	end // else: !if(coarDet)
      
      // common state transitions
      timeStatePipeQ.deq();
      coarPowQ.deq();
      coarInPipeQ.deq();
      fineInPipeQ.deq();
      coarPos <= newCoarPos;

      //setup output data
      if (newCoarPos < fromInteger(lSStart - freqMeanLen) || newCoarPos > fromInteger(lSStart - 1)) // in collect period?
	 begin
            outControl = case (newCoarPos)
                            fromInteger(valueOf(SSyncPos)+8): GainStart;
                            fromInteger(valueOf(GHoldPos)): GHoldStart;
                            default: Idle;
                         endcase;
	 end
      else
	 begin
            if (newCoarPos == fromInteger(lSStart - 1))
               begin
                  outControl = ShortSync;  
                  $write("SHORTSYNC coarPow: ");
                  fxptWrite(6,newCoarPow);
                  $write(" coarCorrPow: ");
                  fxptWrite(6,newCoarCorrPow);
                  $write(" coarPowSq: ");
                  fxptWrite(6,newCoarPowSq);
                  $display("");
                  
                  // buffer the correlation power and the power square
                  `ifdef instantiateStreamCaptureFIFO
                  coarCorrPowReg <= truncate(pack(newCoarCorrPow));
                  coarPowSqReg   <= truncate(pack(newCoarPowSq));
                  `endif
               end
            else
               begin
                  outControl = Collect;
               end
               
// 	    outControl = ((newCoarPos == fromInteger(lSStart - 1)) ? 
// 	                  ShortSync:
// 	                  Collect);
	 end // else: !if(newCoarPos < fromInteger(lSStart - freqMeanLen) || newCoarPos > fromInteger(lSStart - 1))
      outQ.enq(FreqEstInT{control: outControl,
                          data: coarInPipeQ.first(),
                          delayedData: fineInPipeQ.first(),
			  autoCorrelation: newCorr});
      `ifdef debug_mode
      $display("RULE TimeEst.procTimeEstSN: coarPos:%d",newCoarPos);
      `endif
   endrule
   
   `ifdef instantiateStreamCaptureFIFO
   rule enqStreamFIFOs(isValid(coarCorrPowRwire.wget));
      coarCorrPowStreamfifo.enq(fromMaybe(?,coarCorrPowRwire.wget));
      coarPowSqStreamfifo.enq(fromMaybe(?,coarPowSqRwire.wget));
   endrule
   `endif
   
   rule procTimeEstST(!isProlog && timeStatePipeQ.first == STrans);
      timeStatePipeQ.deq();
      coarInPipeQ.deq();
      fineInPipeQ.deq();
      coarPos <= coarPos + 1;
      outQ.enq(FreqEstInT{control: Idle,
			  data: coarInPipeQ.first(),
			  delayedData: fineInPipeQ.first(),
                          autoCorrelation: ?});
      `ifdef debug_mode
      $display("RULE at cycle %d TimeEst.procTimeEstST: coarPos:%d",cycle,coarPos + 1);
      `endif
   endrule

   rule procTimeEstLN(!isProlog && timeStatePipeQ.first == LNormal);
      Bit#(CounterSz) newCoarPos = coarPos+1;
      Bit#(CounterSz) newFinePos = finePos;
      ControlType outControl = Idle;
      let newCorr <- autoCorr.getCorrelation;
      let newFineTimeCorrPow = fpcmplxModSq(fineTimeCorrQ.first);
      $display("PLOTLONGSYNC fineTimeCorrPow: %h",newFineTimeCorrPow);

      if (status2 == LTrans)
	 begin
	    outControl = Idle;
	 end
      else
	 begin
	    if (fineDet)
	       begin
		  newFinePos = finePos + 1; 
	       end
	    else
	       begin
                  if ((newCoarPos == fromInteger(lSyncPos+32)) &&
                      (fineMaxCorrPow > maxFineTimePowSq)) // the max so far must be larger than threshold for it to be accepted
                     begin
                        newFinePos = fromInteger(lSyncPos) + (newCoarPos - fineMaxPos);
		        fineDet <= True;
                        
                        // long sync detected, output data to calculate SNR
                        `ifdef instantiateStreamCaptureFIFO
                        coarCorrPowRwire.wset(coarCorrPowReg);
                        coarPowSqRwire.wset(coarPowSqReg);
                        
                        $display("LONGSYNCPASS coarCorrPow: %d coarPowSq: %d newFinePos:%d",coarCorrPowReg,coarPowSqReg,newFinePos);
                        `endif
		     end
		  else
		     begin
                        if ((newCoarPos < fromInteger(lSyncPos+32)) &&
                            (newFineTimeCorrPow > fineMaxCorrPow)) // new max
                           begin
                              fineMaxCorrPow <= newFineTimeCorrPow;
                              fineMaxPos <= newCoarPos;
                              $display("TimeEst.procTimeEstLN: newFineMaxCorrPow:%h, newFineMaxPos:%d",newFineTimeCorrPow,newCoarPos);
                           end
                        //                `ifdef debug_mode
		        $display("TimeEst.procTimeEstLN: newFineTimeCorrPow:%h, maxFineTimePosSq:%h newCoarPos:%d lSyncPos:%d",newFineTimeCorrPow, maxFineTimePowSq, newCoarPos, lSyncPos);
                        //		`endif
		     end
	       end // else: !if(fineDet)
	   
	   finePos <= newFinePos;
	   coarPos <= newCoarPos;      
	   if (newFinePos == fromInteger(signalStart - 1) || newCoarPos == fromInteger(coarResetPos))
	     begin
		status2 <= LTrans;
		outControl = (newCoarPos == fromInteger(coarResetPos)) ? TimeOut : LongSync;		       
	     end
	   else
	     begin
		outControl = Collect;		       
	     end
	end

      timeStatePipeQ.deq();
      fineTimeCorrQ.deq();
      coarInPipeQ.deq();
      fineInPipeQ.deq();      
      outQ.enq(FreqEstInT{control: outControl,
			  data: coarInPipeQ.first(),
			  delayedData: fineInPipeQ.first(),
                          autoCorrelation: newCorr});
      `ifdef debug_mode
      $display("RULE at cycle %d TimeEst.procTimeEstLN: coarPos:%d, finePos:%d",cycle,newCoarPos,newFinePos);
      `endif
   endrule

   rule procTimeEstLT(!isProlog && timeStatePipeQ.first == LTrans);
      status2 <= LNormal;
      coarPos <= 0;
      finePos <= 0;
      fineMaxCorrPow <= 0 ;
      fineMaxPos <= 0;
      coarDet <= False;
      fineDet <= False; // reset everything
      coarInPipeQ.deq();
      fineInPipeQ.deq();
      timeStatePipeQ.deq();
      outQ.enq(FreqEstInT{control: Idle,
                          data: coarInPipeQ.first(),
			  delayedData: fineInPipeQ.first(),
			  autoCorrelation: ?});
      `ifdef debug_mode
      $display("RULE at cycle %d TimeEst.procTimeEstLT",cycle);
      `endif
   endrule
   
   `ifdef debug_mode
   rule checkFIFOsStatus(True);
      $display("TimeEst.coarTimeInQ notFull:%d notEmpty:%d",coarTimeInQ.notFull,coarTimeInQ.notEmpty);
      $display("TimeEst.coarInPipeQ notFull:%d notEmpty:%d",coarInPipeQ.notFull,coarInPipeQ.notEmpty);
      $display("TimeEst.coarPowQ notFull:%d notEmpty:%d",coarPowQ.notFull,coarPowQ.notEmpty);
      $display("TimeEst.fineTimeInQ notFull:%d notEmpty:%d",fineTimeInQ.notFull,fineTimeInQ.notEmpty);
      $display("TimeEst.fineInPipeQ notFull:%d notEmpty:%d",fineInPipeQ.notFull,fineInPipeQ.notEmpty);
      $display("TimeEst.fineTimeCorrQ notFull:%d notEmpty:%d",fineTimeCorrQ.notFull,fineTimeCorrQ.notEmpty);
      $display("TimeEst.timeStatePipeQ notFull:%d notEmpty:%d",timeStatePipeQ.notFull,timeStatePipeQ.notEmpty);
      $display("TimeEst.outQ notFull:%d notEmpty:%d",outQ.notFull,outQ.notEmpty);      
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
   endrule
   
   `endif

   method Action putCoarTimeIn(FPComplex#(SyncIntPrec,SyncFractPrec) coarTimeIn);
      coarTimeInQ.enq(coarTimeIn);
      `ifdef debug_mode
      $display("METHOD at cycle %d TimeEst.putCoarTimeIn",cycle);   
      `endif
   endmethod

   method Action putFineTimeIn(FineTimeInT fineTimeIn);
      fineTimeInQ.enq(fineTimeIn);
      `ifdef debug_mode
      $display("METHOD at cycle %d TimeEst.putFineTimeIn",cycle);
      `endif
   endmethod
     
   method ActionValue#(FreqEstInT) getFreqEstIn();
      outQ.deq();
      `ifdef debug_mode
      $display("METHOD at cycle %d TimeEst.getFreqEstIn",cycle);
      `endif
      return outQ.first;
   endmethod   
   
   interface ReadOnly readCoarPow = readOnly(coarPow._read);
   
endmodule   

(* synthesize *)
module  mkFreqEstimator(FreqEstimator);
   // Constants
   Integer cordicPipe = valueOf(CORDICPipe);
   Integer cordicIter = valueOf(CORDICIter);
   Integer cordicStep = cordicIter/cordicPipe; // how many stages perform per cycle
   Bit#(RotAngCounterSz) rotAngCounterReset = fromInteger(valueOf(SymbolLen) - 1);
   Nat coarFreqOffAccumRShift = fromInteger(valueOf(CoarFreqOffAccumRShift));
   Nat fineFreqOffAccumRShift = fromInteger(valueOf(FineFreqOffAccumRShift));
   
   // states

   // fifo buffer
   FIFOF#(FreqEstInT) pipeQ <- mkSizedFIFOF(cordicPipe+2); // latency of cordic
   FIFOF#(FreqRotInT) outQ <- mkSizedFIFOF(2);

   // accumulators
   Accumulator#(FreqMeanLen,
                FixedPoint#(SyncIntPrec,SyncFractPrec),
                FixedPoint#(FreqOffAccumIntPrec, SyncFractPrec))   freqOffAccum <- mkAccumulator(fxptSignExtend);
   
   // other regs
   Reg#(FixedPoint#(SyncIntPrec,SyncFractPrec))       freqOff <- mkReg(0);    // combined coar and fine freq off.
   Reg#(FixedPoint#(SyncIntPrec,SyncFractPrec))       rotAng  <- mkReg(0);    // the angle freq rot. should rotate for this sample

   // counters
   Reg#(Bit#(RotAngCounterSz))                        rotAngCounter <- mkReg(0);

   // cordic
   ArcTan#(CorrIntPrec,SyncFractPrec,SyncIntPrec,SyncFractPrec) cordic <- mkArcTan_Pipe(cordicIter,cordicStep); // cos and sin
   
   `ifdef debug_mode
   Reg#(Bit#(64)) cycle <- mkReg(0);
   `endif
   
   rule procIdle(pipeQ.first.control == Idle || pipeQ.first.control == Dump);
      let cordicResult <- cordic.getArcTan;
      let reset = rotAngCounter == rotAngCounterReset;
      let newRotAng = reset ? 0 : rotAng + freqOff;
      pipeQ.deq();
      rotAngCounter <= reset ? 0 : rotAngCounter +  1;
      rotAng <= newRotAng;
      outQ.enq(FreqRotInT{control: pipeQ.first.control,
                          data: pipeQ.first.data,
                          delayedData: pipeQ.first.delayedData,
			  angle: rotAng});
      `ifdef debug_mode
      $display("RULE at cycle %d FreqEst.procIdle",cycle);
      `endif
   endrule

   rule procNotIdle(pipeQ.first.control != Idle && pipeQ.first.control != Dump);
      let cordicResult <- cordic.getArcTan;
      let freqOffAccumAdd = negate(cordicResult); // get freq offset
      let newFreqOffAccum <- freqOffAccum.getNextVal(freqOffAccumAdd);
      pipeQ.deq();
      outQ.enq(FreqRotInT{control: pipeQ.first.control,
			  data: pipeQ.first.data,
                          delayedData: pipeQ.first.delayedData,
			  angle: rotAng});
      if (pipeQ.first.control != Collect) // ShortSync or LongSync
	begin
	   let isShortSync = pipeQ.first.control == ShortSync;
	   let newFreqOff = isShortSync ? 
			    fxptTruncate(newFreqOffAccum >> coarFreqOffAccumRShift) : // reset to coar estimation
			    freqOff + fxptTruncate(newFreqOffAccum >> fineFreqOffAccumRShift); // combine coar and fine estimation
	   freqOff <= newFreqOff;
	   rotAng <= 0; // next sample rotate by 0
	   rotAngCounter <= 0;
           freqOffAccum.clear();
           $write("RULE FreqEst.procNotIdle freqOff: ");
           fxptWrite(4,newFreqOff);
           $display("");
	end
      else
	 begin
//            noAction;
	    rotAng <= rotAng + freqOff;
	 end
      `ifdef debug_mode
      $display("RULE at cycle %d FreqEst.procNotIdle",cycle);
      `endif
   endrule
   
   `ifdef debug_mode
   rule checkFIFO(True);
      $display("FreqEst.pipeQ notFull:%d, notEmpty: %d",pipeQ.notFull(),pipeQ.notEmpty());
      $display("FreqEst.outQ notFull:%d, notEmpty: %d",outQ.notFull(),outQ.notEmpty());
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
   endrule
   `endif
   
   method Action putFreqEstIn(FreqEstInT freqEstIn);
      pipeQ.enq(freqEstIn);
//      if (freqEstIn.control != Idle && freqEstIn.control != Dump)
      cordic.putXY(freqEstIn.autoCorrelation.rel, freqEstIn.autoCorrelation.img); // use cordic
      `ifdef debug_mode
      $display("METHOD at cycle %d FreqEst.putFreqEstIn",cycle);
      `endif
   endmethod
     
   method ActionValue#(FreqRotInT) getFreqRotIn;
      outQ.deq();
      `ifdef debug_mode
      $write("METHOD at cycle %d FreqEst.getFreqRotIn: control:%d, ",cycle, outQ.first.control);
      cmplxWrite("data:("," + ","i), ",fxptWrite(7),outQ.first.data);
      $write("angle:");
      fxptWrite(7, rotAng);
      $display("");
      `endif
      return outQ.first;
   endmethod
endmodule

(* synthesize *)
module  mkFreqRotator(FreqRotator);
   // Integer constants
   Integer cordicPipe = valueOf(CORDICPipe);
   Integer cordicIter = valueOf(CORDICIter);
   Integer cordicStep = cordicIter/cordicPipe; // how many stages perform per cycle
   
   // states
       
   // fifo buffers
   FIFOF#(FreqRotInT)  pipeQ <- mkSizedFIFOF(cordicPipe+2);
   FIFOF#(FreqRotOutT) outQ <- mkSizedFIFOF(2);

   // cordic
   CosAndSin#(SyncIntPrec,SyncFractPrec,SyncIntPrec,SyncFractPrec) cordic <- mkCosAndSin_Pipe(cordicIter,cordicStep); // cos and sin
   
   // register
   Reg#(Bool) rotDelayed <- mkReg(True); // rotate data or delayed data?
   
   `ifdef debug_mode
   Reg#(Bit#(64))      cycle <- mkReg(0);
   `endif
   
   rule procRot(True);
      let freqRotIn = pipeQ.first;
      let control = freqRotIn.control;
      let inCmplx = rotDelayed ? freqRotIn.delayedData : freqRotIn.data;
      let rotAng = freqRotIn.angle;
      let newDelayedData = freqRotIn.data;
      let newOutData = freqRotIn.delayedData;
      let rotCosSinPair <- cordic.getCosSinPair;
      FPComplex#(SyncIntPrec,SyncFractPrec) rotCmplx = fpcmplxTruncate(cmplx(rotCosSinPair.cos, rotCosSinPair.sin));
      FPComplex#(SyncIntPrec,SyncFractPrec) outCmplx = fpcmplxTruncate(fpcmplxMult(inCmplx, rotCmplx));
      if (rotDelayed)
         newOutData = outCmplx;
      else
         newDelayedData = outCmplx;

      if (control == ShortSync)
         rotDelayed <= False;
      else
         if (control == LongSync || control == TimeOut)
            rotDelayed <= True;
      
      pipeQ.deq();
      outQ.enq(FreqRotOutT{control: control,
			   delayedData: newDelayedData,
			   outData: newOutData});
      `ifdef debug_mode
      $write("RULE at cycle %d FreqRot.procRot:",cycle);
      fxptWrite(7, rotAng);
      $display("");      				  
      cmplxWrite("inputCmplx:("," + ","i)",fxptWrite(7),inCmplx);
      $display("");
      cmplxWrite("outCmplx:("," + ","i)",fxptWrite(7),outCmplx);
      $display("");
      `endif
   endrule
   
   `ifdef debug_mode
   rule checkFIFO(True);
      $display("FreqRot.pipeQ notFull:%d, notEmpty: %d",pipeQ.notFull(),pipeQ.notEmpty());
      $display("FreqRot.outQ notFull:%d, notEmpty: %d",outQ.notFull(),outQ.notEmpty());
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
   endrule
   `endif
   
   method Action putFreqRotIn(FreqRotInT freqRotIn);
      pipeQ.enq(freqRotIn);
      let rotAng = freqRotIn.angle;    
      cordic.putAngle(rotAng);
      `ifdef debug_mode
      $display("METHOD at cycle %d FreqRot.putFreqRotIn",cycle);
      `endif
   endmethod
     
   method ActionValue#(FreqRotOutT) getFreqRotOut();
      outQ.deq();
      `ifdef debug_mode
      $display("METHOD at cycle %d FreqRot.getFreqRotOut",cycle);
      `endif
      return outQ.first;
   endmethod   
endmodule   


interface StatefulSynchronizer#(numeric type i_prec, numeric type f_prec);
   interface Synchronizer#(i_prec,f_prec) synchronizer;
   method ControlType controlState;
   interface ReadOnly#(CoarPowType) coarPow;
endinterface

interface GainControlSynchronizer#(numeric type i_prec, numeric type f_prec);
   interface Synchronizer#(i_prec,f_prec) synchronizer;
   interface Get#(ControlType) synchronizerStateUpdate;
   interface ReadOnly#(ControlType) controlState;
   interface ReadOnly#(CoarPowType) coarPow;     
endinterface

/* this sends sync events back to the AD for gain control purposes 
 * it is possible that this guy should be refactored to the FPGA project*/

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkGainControlSynchronizer(GainControlSynchronizer#(SyncIntPrec,SyncFractPrec));
  Reg#(ControlType) ctrlLast <- mkReg(Idle);
  StatefulSynchronizer#(SyncIntPrec,SyncFractPrec) stateSynchronizer <- mkStatefulSynchronizer;
  // We might at some point want to change these to something less wasteful than two fifos.
  // that can be some project for a rainy day.
  FIFO#(ControlType) ctrlQ <- mkFIFO;

  rule setLast;
    ctrlLast <= stateSynchronizer.controlState;
  endrule

  // Broadcast any delta...  Uninterested subscribers will drop it.
  rule generateGHoldStart(stateSynchronizer.controlState != ctrlLast); 
    $display("Synchronizer state broadcast: %d",stateSynchronizer.controlState);
    ctrlQ.enq(stateSynchronizer.controlState);
  endrule

  interface Synchronizer synchronizer = stateSynchronizer.synchronizer;  
  interface Get synchronizerStateUpdate = fifoToGet(ctrlQ);
  interface ReadOnly controlState = readOnly(ctrlLast._read);
  interface ReadOnly coarPow = stateSynchronizer.coarPow;   
endmodule

module[ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkStatefulSynchronizer(StatefulSynchronizer#(SyncIntPrec,SyncFractPrec));
   //input and output buffers
   FIFO#(SynchronizerMesg#(SyncIntPrec,SyncFractPrec)) inQ <- mkLFIFO;
   FIFO#(UnserializerMesg#(SyncIntPrec,SyncFractPrec)) outQ <- mkSizedFIFO(2);
   
   Wire#(ControlType) ctrlWire <- mkDWire(Idle);

   // modules
   TimeEstimator      timeEst <- mkTimeEstimator;
   FreqEstimator      freqEst <- mkFreqEstimator;
   FreqRotator        freqRot <- mkFreqRotator;

   // register
   Reg#(Bool)    lastLongSync <- mkReg(False); // set if the last output is longsync
   Reg#(FPComplex#(SyncIntPrec,SyncFractPrec)) y_last <- mkReg(0); // last result after DC adjustment
   Reg#(FPComplex#(SyncIntPrec,SyncFractPrec)) x_last <- mkReg(0); // last input before DC adjustment

   rule inQToTimeEst(True);
   begin
      inQ.deq();
      timeEst.putCoarTimeIn(inQ.first);
   end
   endrule

   rule timeEstToFreqEst(True);
   begin
      let freqEstIn <- timeEst.getFreqEstIn;
      ctrlWire <= freqEstIn.control;
      ControlType newCtrl = case (freqEstIn.control)
                       GainStart, GHoldStart: Idle; 
                       default: freqEstIn.control;
                    endcase;
      let newFreqEstIn = FreqEstInT{control: newCtrl,
                                    data: freqEstIn.data,
                                    delayedData: freqEstIn.delayedData,
                                    autoCorrelation: freqEstIn.autoCorrelation};
      freqEst.putFreqEstIn(newFreqEstIn);
      `ifdef debug_mode
      $display("ctrlWire %d",freqEstIn.control); 
      `endif
   end
   endrule

   rule freqEstToFreqRot(True);
   begin
      let freqRotIn <- freqEst.getFreqRotIn;
      freqRot.putFreqRotIn(freqRotIn);
   end
   endrule

   rule freqRotToTimeEst(True);
   begin
      let freqRotOut <- freqRot.getFreqRotOut;
      let fineTimeIn = FineTimeInT{control: freqRotOut.control,
                                   delayedData: freqRotOut.delayedData};
      timeEst.putFineTimeIn(fineTimeIn);
      lastLongSync <= (freqRotOut.control == LongSync);
          
      if(freqRotOut.control == LongSync)
        begin
          $display("AutoCorr: LongSync!!!");
        end
      if(freqRotOut.control == ShortSync)
        begin
          $display("AutoCorr: ShortSync!!!");
        end
      if (freqRotOut.control != Dump)
	 begin
	    let syncCtrl = SyncCtrl{isNewPacket: lastLongSync,
				    cpSize: CP0};
	    outQ.enq(UnserializerMesg{control: syncCtrl,
				      data: freqRotOut.outData});
	 end
   end
   endrule

   interface Synchronizer synchronizer;  
     interface Put in;
      method Action put (SynchronizerMesg#(SyncIntPrec,SyncFractPrec) x);
         FPComplex#(SyncIntPrec,SyncFractPrec) y = highPassFilter(hpf_alpha,y_last,x,x_last);
         y_last <= y;
         x_last <= x;
         inQ.enq(x);
         `ifdef debug_mode
         $write("DC Offset before ");
         cmplxWrite("("," + ","i)",fxptWrite(7),x);
         $write(" after ");
         cmplxWrite("("," + ","i)",fxptWrite(7),y);
         $display("");
         `endif
      endmethod
     endinterface
      
     interface out = fifoToGet(outQ);
   endinterface 
   
   method controlState = ctrlWire._read;
      
   interface ReadOnly coarPow = timeEst.readCoarPow; 
endmodule


















