import ClientServer::*;
import GetPut::*;
import Vector::*;
import FixedPoint::*;
import Complex::*;
import FIFO::*;
import FIFOLevel::*;
import FIFOF::*;

`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_magnitude_estimator.bsh"
`include "asim/provides/agc_parameters.bsh"

// The purpose of this is to detect energy edges and adjust them to an appropriate energy level 

typedef Bit#(12) AGCValue;
Integer agcTimeout = 100/20*80*6000/3; //This is sort of a maximum timeout period.

typedef 7 LogMeasurementPeriod;
Integer measurementPeriod = valueof(TExp#(LogMeasurementPeriod));// Two A patterns
typedef 9 SampleIPrec;
typedef 7 SampleFPrec;

typedef FixedPoint#(TAdd#(1,TMul#(SampleIPrec,2)),SampleFPrec) Magnitude;  // Precision matters less here, just make sure we don't overflow. 
typedef FixedPoint#(TAdd#(TMul#(SampleIPrec,2), LogMeasurementPeriod),SampleFPrec) Power;  // Precision matters less here, just make sure we don't overflow. 
typedef Bit#(TMul#(SampleIPrec,2)) AveragePower;

Integer powerDelta = 4; // Need to be 4x Stronger/Weaker

Real defaultAGC = 35;  // figure this out at somepoint

Real magEstIdeal = log2(4000); // Get this empirically from our pipeline. 

interface AGC;
  method Action inputSample(SynchronizerMesg#(SampleIPrec,SampleFPrec) sample);
  method ActionValue#(AGCValue) getAGCUpdate;
endinterface

typedef enum {
  Idle,
  Wait
} AGCState deriving (Bits,Eq);

module mkAGC (AGC);

   Reg#(AGCState) state <- mkReg(Idle);

   FIFO#(Magnitude) infifo <- mkFIFO; // Probably want a little pipeline.
   FIFO#(AGCValue) outfifo <- mkFIFO;

   // Right now, we're using sliding windows.  Perhaps we should just use straight windows.  This simplifies the hardware a lot. fg
   Reg#(Power) powerTemp <- mkReg(0);
   Reg#(Power) currentPower <- mkReg(0);
   Reg#(Power) previousPower <- mkReg(0);
   Reg#(Power) previousPreviousPower <- mkReg(0);
   Reg#(Bit#(20)) timeoutCounter <- mkReg(0);
   Reg#(Bit#(LogMeasurementPeriod)) measurementCounter <- mkReg(0); 
   Reg#(Bit#(TAdd#(2,LogMeasurementPeriod))) waitCounter <- mkReg(0); 
   PulseWire timeoutReset <- mkPulseWire;
   NumTypeParam#(11) bitsLow = ?;
   NumTypeParam#(10) bitsHigh = ?;
   let magnitudeEstimator <- mkLookupBasedEstimator(bitsHigh, bitsLow); 
   FIFO#(Bit#(1)) sendRst <- mkSizedFIFO(1);


   AveragePower currentAvg = truncateLSB(pack(fxptGetInt(currentPower)));
   AveragePower previousAvg = truncateLSB(pack(fxptGetInt(previousPower)));
   AveragePower previousPreviousAvg = truncateLSB(pack(fxptGetInt(previousPreviousPower)));

   // Need a little delay on the rising edge to obtain a good magnitude measure
   Bool risingEdge = (currentAvg > fromInteger(powerDelta) * previousPreviousAvg) &&
                     (previousAvg > fromInteger(powerDelta) * previousPreviousAvg);
   Bool fallingEdge = previousAvg > fromInteger(powerDelta) * currentAvg; 

   

   rule timeout;
     if(timeoutReset) 
       begin
         timeoutCounter <= fromInteger(agcTimeout);
       end
     else if(timeoutCounter > 0)
       begin
         if(timeoutCounter == 1)
           begin
             sendRst.enq(0);
           end
         timeoutCounter <= timeoutCounter - 1;
       end
   endrule

   rule sendReset;
     sendRst.deq;
     let gain <- calculateGainControl(fromReal(defaultAGC));  
     outfifo.enq(gain);
   endrule

   //  Envelope detection code
   rule caclulatePower;
     measurementCounter <= measurementCounter + 1;
     infifo.deq;
     if(measurementCounter + 1 == 0)
       begin
         powerTemp <= 0;
         currentPower <= powerTemp + fxptSignExtend(infifo.first);
         previousPower <= currentPower;
         previousPreviousPower <= previousPower;
         $write("AGC currentPower: ");
         fxptWrite(5,powerTemp + fxptSignExtend(infifo.first));
         $write(" previousPower: ");
         fxptWrite(5, currentPower);
         $write(" previousPreviousPower: ");
         fxptWrite(5, previousPower);
         $display("");
       end
     else
       begin
         powerTemp <= powerTemp + fxptSignExtend(infifo.first);
       end
   endrule


   rule handleIdleRising(state == Idle && risingEdge);
     state <= Wait;
     magnitudeEstimator.request.put(currentAvg); 
     timeoutReset.send;
     waitCounter <= maxBound;
     $display("AGC detects rising edge");
   endrule

   rule handleIdleFalling(state == Idle && fallingEdge);
     state <= Wait;
     let gain <- calculateGainControl(fromReal(defaultAGC));
     outfifo.enq(gain);
     timeoutReset.send;
     waitCounter <= maxBound;
     $display("AGC detects falling edge");
   endrule

 
   rule handleAdjust;
     let magEstCurrent <- magnitudeEstimator.response.get();
     $write("Magnitude Estimate: ");
     fxptWrite(5,magEstCurrent);
     $display("");
     // factor of 10 for converting to decibel. 
     let gain <- calculateGainControl(fromReal(defaultAGC) + (fromReal(magEstIdeal) - 10*magEstCurrent));
     outfifo.enq(gain);
   endrule
  
   // Depending whether we adjust up or down, we could be above or below the previous power level. 
   // Therefore, we should wait until our adjustment settles.
   rule handleWait(state == Wait);
     if(waitCounter - 1 == 0)
       begin
         $display("AGC: wait done");
         state <= Idle;
       end
     waitCounter <= waitCounter - 1;
   endrule

   method Action inputSample(SynchronizerMesg#(9,7) sample);
     infifo.enq(fxptTruncate(fpcmplxModSq(sample)));
   endmethod

   method ActionValue#(AGCValue) getAGCUpdate;
     outfifo.deq;
     return outfifo.first;
   endmethod
endmodule