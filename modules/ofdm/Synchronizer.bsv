import Complex::*;
import FIFO::*;
import FIFOF::*;
import FixedPoint::*;
import GetPut::*;
import Vector::*;

import ofdm_common::*;
import ofdm_parameters::*;
import ofdm_preambles::*;
import ofdm_synchronizer_params::*;
import ofdm_synchronizer_library::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import Controls::*;
// import CORDIC::*;
// import DataTypes::*;
// import FixedPointLibrary::*;
// import Interfaces::*;
// import Preambles::*;
// import ShiftRegs::*;
// import FPComplex::*;
// import Parameters::*;

`define debug_mode True // uncomment this line for displaying text 

typedef struct{
  ctrlT   control;  // estimate postion
  data1T  data1;     // data1
  data2T  data2;     // data2
} SyncData#(type ctrlT, type data1T, type data2T) deriving (Bits, Eq);

typedef enum{
  Dump = 0,          // useless data, don't output
  Idle = 1,          // don't do estimation
  Collect = 2,       // collect correlation and calculate moving average
  ShortSync = 3,     // make coarse estimation
  LongSync = 4,      // make fine estimation
  TimeOut = 5        // timeout reset
} ControlType deriving (Bits, Eq);

typedef enum{
  SNormal = 0,
  STrans = 1,
  LNormal = 2,
  LTrans = 3
} TimeState deriving (Bits, Eq);

// type definitions for the input of timing and frequency synchronizer

// defintion of CorrPipeT: control = tell timing sync what to do, data1 = original input, data2 = rotated input
typedef SyncData#(TimeState, FPComplex#(SyncIntPrec,SyncFractPrec), FPComplex#(SyncIntPrec,SyncFractPrec)) CorrPipeT;

// defintion of FineTimeInT: data1 = original input, data2 = rotated input
typedef SyncData#(ControlType, FPComplex#(SyncIntPrec,SyncFractPrec), FPComplex#(SyncIntPrec,SyncFractPrec)) FineTimeInT;

// definition of FreqEstInT: data1 = original input, data2 = auto correlation result
typedef SyncData#(ControlType, FPComplex#(SyncIntPrec,SyncFractPrec), FPComplex#(CorrIntPrec, SyncFractPrec)) FreqEstInT;

// definition of FreqRotInT: data1 = original input, data2 = angle to be rotated
typedef SyncData#(ControlType, FPComplex#(SyncIntPrec,SyncFractPrec), FixedPoint#(SyncIntPrec, SyncFractPrec)) FreqRotInT;

// timing synchronizer interface (used for both coarse and fine estimations)
interface TimeEstimator;
   // inputs
   method Action putCoarTimeIn(FPComplex#(SyncIntPrec,SyncFractPrec) coarTimeIn);
   method Action putFineTimeIn(FineTimeInT fineTimeIn);

   // output
   method ActionValue#(FreqEstInT) getFreqEstIn();
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
   method ActionValue#(FineTimeInT) getFineTimeIn();
endinterface

interface AutoCorrelator;
   // inputs
   method Action putInput(FPComplex#(SyncIntPrec,SyncFractPrec) x);
   method Action setMode(Bool isShortMode);

   // outputs
   method ActionValue#(CorrType) getCorrelation();
endinterface

// (* synthesize *)
module mkAutoCorrelator(AutoCorrelator);

   // output buffer
   FIFO#(CorrType) outQ <- mkFIFO;

   // delay queues
   ShiftRegs#(SSLen, FPComplex#(SyncIntPrec,SyncFractPrec))             delayIn <- mkAutoCorr_DelayIn;
   ShiftRegs#(SSLen, FPComplex#(MulIntPrec,SyncFractPrec))              corrSub <- mkAutoCorr_CorrSub;
   
   ShiftRegs#(LSLSSLen, FPComplex#(SyncIntPrec,SyncFractPrec))          extDelayIn <- mkAutoCorr_ExtDelayIn;
   ShiftRegs#(LSLSSLen, FPComplex#(MulIntPrec,SyncFractPrec))           extCorrSub <- mkAutoCorr_ExtCorrSub;

   // accumulator
   Reg#(CorrType)                                          corr <- mkReg(cmplx(0,0));

   // mode
   Reg#(Bool) 						   isShort <- mkReg(True); 						   

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
      if (isShort)
	begin
	   delayIn.enq(curIn);
	   corrSub.enq(corrAdd);
	   `ifdef debug_mode
	      $display("AutoCorr.putInput: isShort");
	   `endif
	end
      else
	begin
	   extDelayIn.enq(curIn);
	   delayIn.enq(extDelayIn.first);
	   extCorrSub.enq(corrAdd);
	   corrSub.enq(extCorrSub.first);
	   `ifdef debug_mode
	      $display("AutoCorr.putInput: isLong");
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
         $display("AutoCorr.setMode: %d",isShortMode);
      `endif
   end
   endmethod

   method ActionValue#(CorrType) getCorrelation();
   begin
      outQ.deq;
      `ifdef debug_mode
         $write("AutoCorr.getCorrelation:");
         cmplxWrite("("," + ","i)",fxptWrite(7),outQ.first);
         $display("");
      `endif
      return outQ.first;
   end
   endmethod
     
endmodule

// (* synthesize *)
module mkTimeEstimator(TimeEstimator);
   // constants
   Integer lSStart = valueOf(LSStart);
   Integer signalStart = valueOf(SignalStart);
   Integer lSyncPos = valueOf(LSyncPos);
   Integer freqMeanLen = valueOf(FreqMeanLen);
   Integer coarTimeCorrPos = valueOf(CoarTimeCorrPos);
   Integer coarResetPos = valueOf(TimeResetPos);
   Integer coarTimeAccumDelaySz = valueOf(CoarTimeAccumDelaySz);
   let fullLongPreambles = insertCP0(getLongPreSigns()); // constant known 160-long preambles
   Vector#(FineTimeCorrSz, Complex#(Bit#(1))) longPreambles = take(fullLongPreambles);      
   Bit#(FineTimeCorrFullResSz)  maxFineTimePowSq = cmplxModSq(singleBitCrossCorrelation(longPreambles,longPreambles)) >> 1; // last maxFineTimeSignal 
   
   // states
   // autocorrelator
   AutoCorrelator          autoCorr <- mkAutoCorrelator;

   // input buffers
   FIFO#(FPComplex#(SyncIntPrec,SyncFractPrec)) coarTimeInQ <- mkFIFO; // the buffer should be large enough (> whole latency of synchronizer)
   FIFOF#(FineTimeInT)     fineTimeInQ <- mkFIFOF;

   FIFO#(TimeState) timeStatePipeQ <- mkSizedFIFO(2);
   FIFO#(FPComplex#(SyncIntPrec,SyncFractPrec)) coarInPipeQ <- mkSizedFIFO(2);
   FIFO#(FPComplex#(SyncIntPrec,SyncFractPrec)) fineInPipeQ <- mkSizedFIFO(2);
   FIFO#(FixedPoint#(CoarTimeAccumIntPrec,SyncFractPrec)) coarPowQ <- mkSizedFIFO(2);
   FIFO#(Bit#(FineTimeCorrFullResSz)) fineTimeCorrQ <- mkSizedFIFO(2);
   
   // output buffer
   FIFO#(FreqEstInT) outQ <- mkFIFO;

   // delay queues
   ShiftRegs#(SSLen, FixedPoint#(MulIntPrec,SyncFractPrec))             coarPowSub <- mkTimeEst_CoarPowSub;
   ShiftRegs#(CoarTimeAccumDelaySz, Bool)                  coarTimeSub <- mkTimeEst_CoarTimeSub;
   
   ShiftRegs#(FineTimeCorrDelaySz, Complex#(Bit#(1)))      fineDelaySign <- mkTimeEst_FineDelaySign;

   //accumulators
   Reg#(FixedPoint#(CoarTimeAccumIntPrec,SyncFractPrec))   coarPow <- mkReg(0);
   Reg#(Bit#(CoarTimeAccumIdx))                            coarTime <- mkReg(0); // at most add up to 144

   //other regs
   Reg#(Bit#(CounterSz))                                   coarPos <- mkReg(0);
   Reg#(Bool) 	                                           coarDet <- mkReg(False);
   
   Reg#(Bit#(CounterSz))                                   finePos <- mkReg(0);
   Reg#(Bool) 					           fineDet <- mkReg(False);

   Reg#(Bool) 						   isProlog <- mkReg(True); // setup at the beginning
   Reg#(TimeState) 					   status <- mkReg(SNormal);
   

   rule procProlog(isProlog); // initial setup
   begin
      if (fineTimeInQ.notEmpty) // finish
	begin
	   isProlog <= False;
	end
      else // not yet fill up pipeline, keep sending
	begin
	   outQ.enq(FreqEstInT{control: Dump,
			       data1: ?,
			       data2: ?});	   
	end
      `ifdef debug_mode
         $display("TimeEst.procProlog");
      `endif
   end
   endrule

   rule procAutoCorrSN(!isProlog && status == SNormal);
   begin
      let curIn = coarTimeInQ.first;
      coarTimeInQ.deq;
      fineTimeInQ.deq;
      coarInPipeQ.enq(curIn);
      if (fineTimeInQ.first.control == ShortSync)
	begin
	   status <= LNormal;
	   autoCorr.setMode(False);
	   timeStatePipeQ.enq(STrans);
	end
      else
	begin
	   FixedPoint#(MulIntPrec,SyncFractPrec) coarPowAdd = fxptTruncate(fpcmplxModSq(curIn));
	   let newCoarPow = coarPow +
			    fxptZeroExtend(coarPowAdd) -
			    fxptZeroExtend(coarPowSub.first);
	   coarPow <= newCoarPow;
	   coarPowQ.enq(newCoarPow);
	   coarPowSub.enq(coarPowAdd);
	   autoCorr.putInput(curIn);
	   timeStatePipeQ.enq(SNormal);
	end // else: !if(fineTimeInQ.first.control == ShortSync)
      `ifdef debug_mode
         $display("TimeEst.procAutoCorrSN");
      `endif
   end
   endrule

   rule  procAutoCorrLN(!isProlog && status == LNormal);
   begin
      let fineSign = toSingleBitCmplx(fineTimeInQ.first.data2);
      let fineTimeCorrIn = append(fineDelaySign.getVector(), cons(fineSign,nil));
      let newFineTimeCorrPow = cmplxModSq(singleBitCrossCorrelation(fineTimeCorrIn, longPreambles));
      fineDelaySign.enq(fineSign);
      fineTimeCorrQ.enq(newFineTimeCorrPow);
      coarTimeInQ.deq;
      fineTimeInQ.deq;
      autoCorr.putInput(fineTimeInQ.first.data2);	
      timeStatePipeQ.enq(LNormal);
      coarInPipeQ.enq(coarTimeInQ.first);
      fineInPipeQ.enq(fineTimeInQ.first.data1);
      `ifdef debug_mode
         $write("TimeEst.procAutoCorrLN: fineSign: %d + %di,",fineSign.rel,fineSign.img);
         $write("input: ");
         cmplxWrite("("," + ","i), ",fxptWrite(7),fineTimeInQ.first.data2);
         $display("");
         $display("TimeEst.procAutoCorrLN: fineTimeCorrIn:%h, ",fineTimeCorrIn);
         $display("TimeEst.procAutoCorrLN: longPreSigns:%h, ",longPreambles);
      `endif
   end
   endrule

   rule procAutoCorrLT(!isProlog && status == LTrans);
   begin
      fineTimeInQ.deq;
      timeStatePipeQ.enq(LTrans);
      fineInPipeQ.enq(fineTimeInQ.first.data1);
      if (fineTimeInQ.first.control == LongSync || fineTimeInQ.first.control == TimeOut)
	begin
	   status <= SNormal;
	   autoCorr.setMode(True);
	end
      `ifdef debug_mode
         $display("TimeEst.procAutCorrLT");
      `endif
   end
   endrule

   rule procTimeEstSN(!isProlog && timeStatePipeQ.first == SNormal);
   begin
      //variables
      ControlType outControl = Idle;
      FPComplex#(SyncIntPrec,SyncFractPrec) outData = coarInPipeQ.first;
      CorrType outCorr = ?;
      Bit#(CounterSz) newCoarPos;
      let newCorr <- autoCorr.getCorrelation;
      let newCoarPow = coarPowQ.first;

      if (coarDet)
	begin
	   newCoarPos = coarPos + 1;
	end
      else
	begin
	   FPComplex#(CoarTimeAccumIntPrec, SyncFractPrec) newCoarCorr = fpcmplxTruncate(newCorr);
	   let newCoarCorrPow = fpcmplxModSq(newCoarCorr);
	   let newCoarPowSq = fxptZeroExtend(fxptMult(newCoarPow,newCoarPow));
	   let coarTimeAdd = newCoarCorrPow > (newCoarPowSq >> 1);
	   let newCoarTime = coarTime +
			     zeroExtend(pack(coarTimeAdd)) -
			     zeroExtend(pack(coarTimeSub.first));
	   newCoarPos = zeroExtend(newCoarTime) +
	       		fromInteger(coarTimeCorrPos - 1);
	   if (newCoarTime == fromInteger(coarTimeAccumDelaySz)) // coar detected
	     begin
		coarDet <= True;
		coarTime <= 0;     // reset coarTime
		coarTimeSub.clear; // clear coarTimeSub shiftreg
	     end
	   else
	     begin
		coarTimeSub.enq(coarTimeAdd);
		coarTime <= newCoarTime;
	     end
	end // else: !if(coarDet)
      
      // common state transitions
      timeStatePipeQ.deq;
      coarPowQ.deq;
      coarInPipeQ.deq;
      coarPos <= newCoarPos;

      //setup output data
      if (newCoarPos < fromInteger(lSStart - freqMeanLen) || newCoarPos > fromInteger(lSStart - 1))
	begin
	   outControl = Idle;
	   outCorr = ?;
	end
      else
	begin
	   outControl = ((newCoarPos == fromInteger(lSStart - 1)) ? 
			 ShortSync:
			 Collect);
	   outCorr = newCorr;
	end // else: !if(newCoarPos < fromInteger(lSStart - freqMeanLen) || newCoarPos > fromInteger(lSStart - 1))
      outQ.enq(FreqEstInT{control: outControl,
			  data1: outData,
			  data2: outCorr});
      `ifdef debug_mode
         $display("TimeEst.procTimeEstSN: coarPos:%d",newCoarPos);
      `endif
   end
   endrule

   rule procTimeEstST(!isProlog && timeStatePipeQ.first == STrans);
   begin
      timeStatePipeQ.deq;
      coarInPipeQ.deq;
      coarPos <= coarPos + 1;
      outQ.enq(FreqEstInT{control: Idle,
			  data1: coarInPipeQ.first,
			  data2: ?});
      `ifdef debug_mode
         $display("TimeEst.procTimeEstST: coarPos:%d",coarPos + 1);
      `endif
   end
   endrule

   rule procTimeEstLN(!isProlog && timeStatePipeQ.first == LNormal);
   begin
      Bit#(CounterSz) newCoarPos = coarPos;
      Bit#(CounterSz) newFinePos = finePos;
      ControlType outControl = Idle;
      FPComplex#(SyncIntPrec,SyncFractPrec) outData = ?;
      CorrType outCorr = ?;
      let newCorr <- autoCorr.getCorrelation;
      let newFineTimeCorrPow = fineTimeCorrQ.first;

      if (status == LTrans)
	begin
	   outControl = Idle;
	   outData = fineInPipeQ.first; // send  outData as fineInPipeQ.first
	   outCorr = ?;
	end
      else
	begin
	   if (fineDet)
	     begin
		newFinePos = finePos + 1; 
	     end
	   else
	     begin
		if (newFineTimeCorrPow > maxFineTimePowSq)
		  begin
		     newFinePos = fromInteger(lSyncPos); 
		     fineDet <= True;
		  end
		else
		  begin
		     newCoarPos = coarPos + 1;
		  end
                `ifdef debug_mode
		   $display("TimeEst.procTimeEstLN: newFineTimePowCorr:%d, maxFineTimePosSq:%d",newFineTimeCorrPow, maxFineTimePowSq);
		`endif
	     end // else: !if(fineDet)
	   
	   coarInPipeQ.deq;
	   finePos <= newFinePos;
	   coarPos <= newCoarPos;
	   outData = coarInPipeQ.first;
	   outCorr = newCorr;
      
	   if (newFinePos == fromInteger(signalStart - 1) || newCoarPos == fromInteger(coarResetPos))
	     begin
		status <= LTrans;
		outControl = (newCoarPos == fromInteger(coarResetPos)) ? TimeOut : LongSync;		       
	     end
	   else
	     begin
		outControl = Collect;		       
	     end
	end
      
      timeStatePipeQ.deq;
      fineTimeCorrQ.deq;
      fineInPipeQ.deq;      
      outQ.enq(FreqEstInT{control: outControl,
			  data1: outData,
			  data2: outCorr});
      `ifdef debug_mode
         $display("TimeEst.procTimeEstLN: coarPos:%d, finePos:%d",newCoarPos,newFinePos);
      `endif
   end // else: !if(status == LTrans)
   endrule

   rule procTimeEstLT(!isProlog && timeStatePipeQ.first == LTrans);
   begin
      coarPos <= 0;
      finePos <= 0;
      coarDet <= False;
      fineDet <= False; // reset everything
      fineInPipeQ.deq;
      timeStatePipeQ.deq;
      outQ.enq(FreqEstInT{control: Idle,
			  data1: fineInPipeQ.first,
			  data2: ?});
      `ifdef debug_mode
         $display("TimeEst.procTimeEstLT");
      `endif
   end // case: LTrans
   endrule


   method Action putCoarTimeIn(FPComplex#(SyncIntPrec,SyncFractPrec) coarTimeIn);
   begin
      coarTimeInQ.enq(coarTimeIn);
      `ifdef debug_mode
         $display("TimeEst.putCoarTimeIn");   
      `endif
   end
   endmethod

   method Action putFineTimeIn(FineTimeInT fineTimeIn);
   begin
      fineTimeInQ.enq(fineTimeIn);
      `ifdef debug_mode
         $display("TimeEst.putFineTimeIn");
      `endif
   end
   endmethod
     
   method ActionValue#(FreqEstInT) getFreqEstIn();
   begin
      outQ.deq;
      `ifdef debug_mode
         $display("TimeEst.getFreqEstIn");
      `endif
      return outQ.first;
   end
   endmethod   
endmodule   

// (* synthesize *)
module [Module] mkFreqEstimator(FreqEstimator);
   // Constants
   Integer cordicPipe = valueOf(CORDICPipe);
   Integer cordicIter = valueOf(CORDICIter);
   Integer cordicStep = cordicIter/cordicPipe; // how many stages perform per cycle
   Bit#(RotAngCounterSz) rotAngCounterReset = fromInteger(valueOf(SymbolLen) - 1);
   Nat coarFreqOffAccumRShift = fromInteger(valueOf(CoarFreqOffAccumRShift));
   Nat fineFreqOffAccumRShift = fromInteger(valueOf(FineFreqOffAccumRShift));
   
   // states

   // fifo buffer
   FIFO#(FreqEstInT) pipeQ <- mkSizedFIFO(cordicPipe+2);
   FIFO#(FreqRotInT) outQ <- mkFIFO;

   // shift registers
   ShiftRegs#(FreqMeanLen, FixedPoint#(SyncIntPrec,SyncFractPrec)) freqOffAccumSub <- mkFreqEst_FreqOffAccumSub;  

   // accumulators
   Reg#(FixedPoint#(FreqOffAccumIntPrec,SyncFractPrec))   freqOffAccum <- mkReg(0);     // freq offset accumulators
   Reg#(FixedPoint#(SyncIntPrec,SyncFractPrec))               freqOff <- mkReg(0);           // combined coar and fine freq off.
   Reg#(FixedPoint#(SyncIntPrec,SyncFractPrec))               rotAng <- mkReg(0);            // the angle freq rot. should rotate for this sample

   // counters
   Reg#(Bit#(RotAngCounterSz))                        rotAngCounter <- mkReg(0);

   // cordic
   ArcTan#(CorrIntPrec,SyncFractPrec,SyncIntPrec,SyncFractPrec) cordic <- mkArcTan_Pipe(cordicIter,cordicStep); // cos and sin

   rule procIdle(pipeQ.first.control == Idle || pipeQ.first.control == Dump);
   begin
      let reset = rotAngCounter == rotAngCounterReset;
      let newRotAng = reset ? 0 : rotAng + freqOff;
      pipeQ.deq;
      rotAngCounter <= reset ? 0 : rotAngCounter +  1;
      rotAng <= newRotAng;
      outQ.enq(FreqRotInT{control: pipeQ.first.control,
			  data1: pipeQ.first.data1,
			  data2: rotAng});
   end
   endrule

   rule procNotIdle(pipeQ.first.control != Idle && pipeQ.first.control != Dump);
   begin
      let cordicResult <- cordic.getArcTan;
      let freqOffAccumAdd = negate(cordicResult); // get freq offset
      let newFreqOffAccum = freqOffAccum + 
			    fxptSignExtend(freqOffAccumAdd) -
			    fxptSignExtend(freqOffAccumSub.first);
      pipeQ.deq;
      outQ.enq(FreqRotInT{control: pipeQ.first.control,
			  data1: pipeQ.first.data1,
			  data2: rotAng});
      if (pipeQ.first.control != Collect)
	begin
	   let isShortSync = pipeQ.first.control == ShortSync;
	   let newFreqOff = isShortSync ? 
			    fxptTruncate(newFreqOffAccum >> coarFreqOffAccumRShift) : // reset to coar estimation
			    freqOff + fxptTruncate(newFreqOffAccum >> fineFreqOffAccumRShift); // combine coar and fine estimation
	   freqOff <= newFreqOff;
	   rotAng <= 0; // next sample rotate by 0
	   rotAngCounter <= 0;
	   freqOffAccum <= 0;     // clear
	   freqOffAccumSub.clear; // clear
	end
      else
	begin
	   freqOffAccumSub.enq(freqOffAccumAdd);
	   rotAng <= rotAng + freqOff;
	   freqOffAccum <= newFreqOffAccum;
	end
   end
   endrule

   method Action putFreqEstIn(FreqEstInT freqEstIn);
   begin
      pipeQ.enq(freqEstIn);
      if (freqEstIn.control != Idle && freqEstIn.control != Dump)
	cordic.putXY(freqEstIn.data2.rel, freqEstIn.data2.img); // use cordic
   end
   endmethod
     
   method ActionValue#(FreqRotInT) getFreqRotIn;
   begin
      outQ.deq;
      `ifdef debug_mode
         $write("FreqEst.getFreqRotIn: control:%d, ",outQ.first.control);
         cmplxWrite("data:("," + ","i), ",fxptWrite(7),outQ.first.data1);
         $write("angle:");
         fxptWrite(7, rotAng);
         $display("");
      `endif
      return outQ.first;
   end
   endmethod
endmodule

// (* synthesize *)
module [Module] mkFreqRotator(FreqRotator);
   // Integer constants
   Integer cordicPipe = valueOf(CORDICPipe);
   Integer cordicIter = valueOf(CORDICIter);
   Integer cordicStep = cordicIter/cordicPipe; // how many stages perform per cycle
   
   // states
       
   // fifo buffers
   FIFO#(FreqRotInT)  pipeQ <- mkSizedFIFO(cordicPipe+2);
   FIFO#(FineTimeInT) outQ <- mkFIFO;

   // cordic
   CosAndSin#(SyncIntPrec,SyncFractPrec,SyncIntPrec,SyncFractPrec) cordic <- mkCosAndSin_Pipe(cordicIter,cordicStep); // cos and sin
   
   rule procRot(True);
   begin
      let freqRotIn = pipeQ.first;
      let control = freqRotIn.control;
      let inCmplx = freqRotIn.data1;
      let rotAng = freqRotIn.data2;
      let rotCosSinPair <- cordic.getCosSinPair;
      FPComplex#(SyncIntPrec,SyncFractPrec) rotCmplx = fpcmplxTruncate(cmplx(rotCosSinPair.cos, rotCosSinPair.sin));
      FPComplex#(SyncIntPrec,SyncFractPrec) outCmplx = fpcmplxTruncate(fpcmplxMult(inCmplx, rotCmplx));
      pipeQ.deq;
      outQ.enq(FineTimeInT{control: control,
			   data1: inCmplx,
			   data2: outCmplx});
      `ifdef debug_mode
         $write("FreqRot.procRot:");
         fxptWrite(7, rotAng);
         $display("");      				  
         cmplxWrite("inputCmplx:("," + ","i)",fxptWrite(7),inCmplx);
         $display("");
         cmplxWrite("outCmplx:("," + ","i)",fxptWrite(7),outCmplx);
         $display("");
      `endif
   end
   endrule
   
   method Action putFreqRotIn(FreqRotInT freqRotIn);
   begin
      pipeQ.enq(freqRotIn);
      let rotAng = freqRotIn.data2;    
      cordic.putAngle(rotAng);
   end
   endmethod
     
   method ActionValue#(FineTimeInT) getFineTimeIn();
   begin
      outQ.deq;
      return outQ.first;
   end
   endmethod   
endmodule   

// (* synthesize *)
module [Module] mkSynchronizer(Synchronizer#(SyncIntPrec,SyncFractPrec));
   //input and output buffers
   FIFO#(SynchronizerMesg#(SyncIntPrec,SyncFractPrec)) inQ <- mkLFIFO;
   FIFO#(UnserializerMesg#(SyncIntPrec,SyncFractPrec)) outQ <- mkSizedFIFO(2);

   // modules
   TimeEstimator      timeEst <- mkTimeEstimator;
   FreqEstimator      freqEst <- mkFreqEstimator;
   FreqRotator        freqRot <- mkFreqRotator;

   // register
   Reg#(Bool)    lastLongSync <- mkReg(False); // set if the last output is longsync

   rule inQToTimeEst(True);
   begin
      inQ.deq;
      timeEst.putCoarTimeIn(inQ.first);
   end
   endrule

   rule timeEstToFreqEst(True);
   begin
      let freqEstIn <- timeEst.getFreqEstIn;
      freqEst.putFreqEstIn(freqEstIn);
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
      let fineTimeIn <- freqRot.getFineTimeIn;
      timeEst.putFineTimeIn(fineTimeIn);
      lastLongSync <= (fineTimeIn.control == LongSync);
      if (fineTimeIn.control != Dump)
	 begin
	    let syncCtrl = SyncCtrl{isNewPacket: lastLongSync,
				    cpSize: CP0};
	    outQ.enq(UnserializerMesg{control: syncCtrl,
				      data: fineTimeIn.data2});
	 end
   end
   endrule
   
   interface in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule


















