import FIFO::*;
import FIFOF::*;
import FixedPoint::*;
import CBus::*;
import GetPut::*;
import ClientServer::*;
import Vector::*;

// import StreamCaptureFIFO::*;
// import CBusUtils::*;

// import Synchronizer::*;
// import FPGAParameters::*;
// import MACPhyParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/stream_capture_fifo.bsh"

typedef Server#(CoarPowType,Int#(10)) GainAdjuster;

interface AGC; 
  interface Put#(ControlType) synchronizerStateUpdate;
  interface Put#(RXExternalFeedback) packetFeedback;
  method Action inputPower(CoarPowType power);
  method Bit#(10) outputGain();
endinterface

typedef enum {
  Sweeping = 0,
  Frozen = 1,
  Adjusting = 2,
  Packet = 3, // Waiting for packet decode
  Abort = 4
} GainState deriving (Bits,Eq);


// The following are 'magic' typedefs that were obtained empirically
typedef 32'h1040   ExpectedPowerHigh; // 1.25 * 32'hd00 = 32'h1040
typedef 32'hd00   ExpectedPowerLow;
typedef TExp#(20) SweepTimeout; // 1 MillionCycles? not enough
typedef 360       CalibrationGain;
typedef 580       GainMin;
typedef 20        GainMax;
typedef 64        ShortSyncAdjustDelay; // how long it takes to update the gain.  may want to adjust this at some point.
typedef 512       SweepAdjustDelay; // how long before changing the gain again in sweep mode?


// most everything here should be baseband...
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkAGC (AGC);
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXGain = CRAddr{a: fromInteger(valueof(AddrRXGain)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXGainMin = CRAddr{a: fromInteger(valueof(AddrRXGainMin)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXGainMax = CRAddr{a: fromInteger(valueof(AddrRXGainMax)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrDCCCalibration = CRAddr{a: fromInteger(valueof(AddrDCCCalibration)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrDirectGainControl = CRAddr{a: fromInteger(valueof(AddrDirectGainControl)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrDirectGain = CRAddr{a: fromInteger(valueof(AddrDirectGain)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrAGCState = CRAddr{a: fromInteger(valueof(AddrAGCState)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrAGCSweepEntries = CRAddr{a: fromInteger(valueof(AddrAGCSweepEntries)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSweepTimeoutStart = CRAddr{a: fromInteger(valueof(AddrSweepTimeoutStart)) , o: 0};


  Reg#(Bit#(10)) rxGain <- mkCBRegR(addrRXGain,fromInteger(valueof(CalibrationGain)));
  Reg#(Bit#(10)) directGain <- mkCBRegRW(addrDirectGain,fromInteger(valueof(CalibrationGain)));
  Reg#(Bit#(10)) rxGainMax <- mkCBRegRW(addrRXGainMax,fromInteger(valueof(GainMax)));
  Reg#(Bit#(10)) rxGainMin <- mkCBRegRW(addrRXGainMin,fromInteger(valueof(GainMin)));
  Reg#(Bit#(1)) calibrationMode <- mkCBRegRW(addrDCCCalibration,0);
  Reg#(Bit#(1)) directGainControl <- mkCBRegRW(addrDirectGainControl,0);
  Reg#(Bit#(10)) delay <- mkReg(0);   
  Reg#(Bit#(10)) sweepDelay <- mkReg(0);   
  Reg#(GainState) gainState <- mkCBRegR(addrAGCState,Sweeping);
  Reg#(Bit#(32)) sweepEntries <- mkCBRegR(addrAGCSweepEntries,0);
  RWire#(CoarPowType) powerWire <- mkRWire();
  RWire#(ControlType) syncWire <-mkRWire;
  FIFOF#(RXExternalFeedback) feedbackFIFO <- mkFIFOF;
  FIFOF#(CoarPowType) streamfifo <- mkStreamCaptureFIFOF(512);
  mkCBusGet(valueof(AddrAGCStreamFifoOffset),fifoToGet(fifofToFifo(streamfifo)));
  Reg#(Bit#(32)) sweepTimeout <- mkReg(fromInteger(valueof(SweepTimeout)));
  Reg#(Bit#(32)) sweepTimeoutStart <- mkCBRegRW(addrSweepTimeoutStart,fromInteger(valueof(SweepTimeout)));
  Reg#(Bool) sweepUp <- mkReg(False);
  Reg#(Bit#(10)) adjustmentCounter <- mkReg(0);
  Reg#(Bool) provisionalAdjusting <- mkReg(True);
  Reg#(Bit#(32)) cycleCounter <- mkReg(0);
  GainAdjuster gainAdjuster <- mkGainAdjusterThreshold;

  
  // states in which we are allowed to observe synch output/sweep
  Bool searching = (gainState != Packet) && (calibrationMode == 0); // don't try to adjust gain during packet duration or calibration
  Bool adjustReady = (delay == 0) && (directGainControl == 0);
  Bool sweepReady =  (sweepDelay == 0) && (directGainControl == 0);

  rule tickCounter;
    cycleCounter <= cycleCounter + 1;
  endrule

   // by queueing this on data, we introduce the possibility of deadlock this might not be too desirable...
   // we may instead introduce a data payload completion timeout
   rule startSweep(syncWire.wget matches tagged Invalid &&& !feedbackFIFO.notEmpty);
     if(sweepTimeout == 0) 
       begin
         sweepEntries <= sweepEntries + 1;
       end
     if((sweepTimeout == 0 && searching) || (gainState == Abort && provisionalAdjusting))
       begin
         $display("AGC: switching to sweeping state");
         gainState <= Sweeping;
         sweepTimeout <= sweepTimeoutStart;
         provisionalAdjusting <= True;
       end
     else if(sweepTimeout != 0)
       begin
         sweepTimeout <= sweepTimeout - 1;
       end
   endrule

   // always counuter down if non-zero
   rule tickDelay(delay != 0);
     delay <= delay - 1;
   endrule
   
   // always counuter down if non-zero
   rule tickSweepDelay(sweepDelay != 0);
     sweepDelay <= sweepDelay - 1;
   endrule
   
   rule enqStream(powerWire.wget matches tagged Valid .power);
     streamfifo.enq(power);
   endrule
   
   // adjust sweep gain
   rule handlePowerSweep(syncWire.wget matches tagged Invalid &&& sweepReady && searching && gainState == Sweeping);
    if(sweepUp) 
      begin
        if(rxGain >= rxGainMin) // reach largest value (smallest gain) already , reverse trend
          begin
            sweepUp <= !sweepUp;
          end
        else
          begin
            sweepDelay <= fromInteger(valueof(SweepAdjustDelay)); // reset counter
            rxGain <= rxGain + 1; // incr gain value (= lower gain)
            adjustmentCounter <= 0; 
          end
      end
    else
      begin
        if(rxGain <= rxGainMax) // reach smallest value (largest gain) already, reverse tred
          begin
            sweepUp <= !sweepUp;
          end
        else
          begin
            sweepDelay <= fromInteger(valueof(SweepAdjustDelay)); // reset sweep adjust count down counter
            rxGain <= rxGain - 1; // decr gain value (= higher gain)
            adjustmentCounter <= 0; 
          end
      end
   endrule
   
   
   rule handlePowerAdjusting(adjustReady && searching && gainState == Adjusting);
    Int#(10) adjustmentSuggested <- gainAdjuster.response.get;    
    delay <= fromInteger(valueof(ShortSyncAdjustDelay));

    $display("AGC gain @ %d : %h, proposed adjust: %d ", cycleCounter, rxGain, adjustmentSuggested);
    if(adjustmentSuggested < 0 && (rxGainMax - pack(adjustmentSuggested) > rxGain)) // rxGain + adjustment < rxGainMax
      begin
        rxGain <= rxGainMax;
        adjustmentCounter <= adjustmentCounter + (rxGain - rxGainMax);
      end
    else if(adjustmentSuggested > 0 && (rxGainMin - pack(adjustmentSuggested) < rxGain)) // rxGain + adjustment > rxGainMin
      begin
        rxGain <= rxGainMin;
        adjustmentCounter <= adjustmentCounter - (rxGainMin - rxGain);
      end
    else //Normal case
      begin 
        rxGain <= rxGain + pack(adjustmentSuggested);
        adjustmentCounter <= adjustmentCounter - pack(adjustmentSuggested);
      end
  endrule
   
   // always put the new power value to the gain adjuster
  rule drivePower(powerWire.wget matches tagged Valid .power);
    gainAdjuster.request.put(power);
    $display("AGC power: %h ", power);
  endrule

  rule dispState;
    $display("AGC @ %d : state: %d", cycleCounter, gainState);
  endrule

  // does this conflict, can we drop this state?
  rule handleAbort(calibrationMode == 0 && directGainControl == 0 && gainState == Abort);
    rxGain <= rxGain + signExtend(adjustmentCounter); // reverse the adjustment that has been made 
    delay <= fromInteger(valueof(ShortSyncAdjustDelay));
    adjustmentCounter <= 0;
  endrule

  //S Walking down a dark path with this comparison
  // do we want to do this in calibration
  rule setStateSync(syncWire.wget matches tagged Valid .syncState &&& searching &&& !feedbackFIFO.notEmpty);
    case(syncState)
      GainStart: begin
                   $display("AGC: GainStart @ %d", cycleCounter);
                   gainState <= Adjusting;                   
                 end
      GHoldStart: 
                 begin
                   gainState <= Frozen;
                   $display("AGC: GHoldStart @ %d", cycleCounter);
                 end
      TimeOut:   begin
                   $display("AGC: TimeOut @ %d", cycleCounter);
                   gainState <= Abort;
                 end
     // LongSync:  begin
     //             $display("AGC: LongSync @ %d", cycleCounter);
     //             gainState <= Packet;                   
     //            end
    endcase
  endrule



  rule headerStateAdjust(calibrationMode == 0 && feedbackFIFO.notEmpty);
    feedbackFIFO.deq;
    case(feedbackFIFO.first)
      LongSync:
        begin
          $display("AGC: LongSync @ %d", cycleCounter);
          gainState <= Packet;
        end
      HeaderDecoded:  
        begin
          $display("AGC: HeaderDecoded @ %d", cycleCounter);
          provisionalAdjusting <= False; 
          sweepTimeout <= sweepTimeoutStart; // header decoded correctly, reset sweep timeout
          adjustmentCounter <= 0;           
        end 
      DataComplete:
        begin
          provisionalAdjusting <= False; 
          adjustmentCounter <= 0;           
          $display("AGC: DataComplete @ %d", cycleCounter);
          sweepTimeout <= sweepTimeoutStart;
          gainState <= Frozen;
        end
      Abort:
        begin
          $display("AGC: Abort @ %d", cycleCounter);
          gainState <= Abort;
        end
    endcase
  endrule



  // direct gain control = no adjustment
  rule setDirectGainControl(directGainControl == 1 && calibrationMode == 0);
    rxGain <= directGain;
  endrule
   
  // calibration gain value need to be use for calibration
  rule setCalibrationGain(calibrationMode == 1);
    rxGain <= fromInteger(valueof(CalibrationGain));
  endrule


  interface Put synchronizerStateUpdate;
    method Action put(ControlType ctrl);
      syncWire.wset(ctrl);
    endmethod
  endinterface

  interface Put packetFeedback;
    method Action put(RXExternalFeedback feedback);
      feedbackFIFO.enq(feedback);
    endmethod
  endinterface

  method Action inputPower(CoarPowType power);
    powerWire.wset(power);
  endmethod

  method Bit#(10) outputGain();
    return rxGain;
  endmethod

endmodule


// Recall, we see power ~ amplitude squared...
// This module recommends a power adjustment.
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkGainAdjusterSimple (GainAdjuster);
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXGainPowerThresholdLow = CRAddr{a: fromInteger(valueof(AddrRXGainPowerThresholdLow)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXGainPowerThresholdHigh = CRAddr{a: fromInteger(valueof(AddrRXGainPowerThresholdHigh)) , o: 0};


  Reg#(CoarPowType) powerThresholdLow <- mkCBRegRW(addrRXGainPowerThresholdLow,unpack(fromInteger(valueof(ExpectedPowerLow))));
  Reg#(CoarPowType) powerThresholdHigh <- mkCBRegRW(addrRXGainPowerThresholdHigh,unpack(fromInteger(valueof(ExpectedPowerHigh))));
  RWire#(Int#(10)) adjustWire <- mkRWire();

  interface Put request;
     method Action put(CoarPowType power);
       if(power < powerThresholdLow)
         begin
            adjustWire.wset(-1);      
         end
       else if(power > powerThresholdHigh)
         begin
           adjustWire.wset(1);               
         end
     endmethod
  endinterface

  interface Get response;  
    method ActionValue#(Int#(10)) get() if(adjustWire.wget() matches tagged Valid .value);
      return value;
    endmethod
  endinterface

endmodule


module mkMagnitudeEstimator (Server#(Bit#(length), Bit#(TLog#(length))));

  function takeMax(Maybe#(Bit#(TLog#(length))) a, Maybe#(Bit#(TLog#(length))) b);
    let retVal = tagged Invalid;
    if(a matches tagged Valid .indexA &&& b matches tagged Valid .indexB) 
      begin
        if(indexA > indexB)
          begin
            retVal = a;
          end 
        else
          begin
            retVal = b;
          end 
      end
    else if(a matches tagged Valid .indexA)
      begin
        retVal = a;
      end
    else if(b matches tagged Valid .indexB)
      begin
        retVal = b;
      end
    return retVal;
  endfunction 

  function Vector#(length,Maybe#(Bit#(TLog#(length)))) buildIndexVector(Bit#(length) value);
    Vector#(length,Maybe#(Bit#(TLog#(length)))) vecs = replicate(tagged Invalid);
    for(Integer i = 0; i <  valueof(length); i = i + 1)
       begin
         if(value[i] == 1)
           begin
             vecs[i] = tagged Valid fromInteger(i);
           end
         else
           begin
             vecs[i] = tagged Invalid;
           end
       end
    return vecs;
  endfunction

  interface Put request;
     method Action put(Bit#(length) value);
       let maxIndex = fold(takeMax,buildIndexVector(value));
     endmethod
  endinterface

  interface Get response;  
    method ActionValue#(Bit#(TLog#(length))) get();
      return 0;
    endmethod
  endinterface
endmodule




module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkGainAdjusterThreshold (GainAdjuster);
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXGainPowerThresholdLow = CRAddr{a: fromInteger(valueof(AddrRXGainPowerThresholdLow)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXGainPowerThresholdHigh = CRAddr{a: fromInteger(valueof(AddrRXGainPowerThresholdHigh)) , o: 0};


  Reg#(CoarPowType) powerThresholdLow <- mkCBRegRW(addrRXGainPowerThresholdLow,unpack(fromInteger(valueof(ExpectedPowerLow))));
  Reg#(CoarPowType) powerThresholdHigh <- mkCBRegRW(addrRXGainPowerThresholdHigh,unpack(fromInteger(valueof(ExpectedPowerHigh))));
  // 16 per dB, recall that power is squared
  //                                                 
  Int#(10) powerTable[10] = {72,48,24,14,1,-1,-10,-24,-48,-72};

  RWire#(Int#(10)) adjustWire <- mkRWire();

  interface Put request;
     method Action put(CoarPowType power);
       if(power < powerThresholdLow * 0.125) // need to amp up power for 4.5dB
         begin
            adjustWire.wset(powerTable[9]);      
         end
       else if(power < powerThresholdLow * 0.25) // need to amp up power for 3dB
         begin
            adjustWire.wset(powerTable[8]);      
         end
       else if(power < powerThresholdLow * 0.5) // need to amp up power for 1.5dB
         begin
            adjustWire.wset(powerTable[7]);      
         end
       else if(power < powerThresholdLow - powerThresholdLow * 0.25) // need to amp up power for 0.625dB
         begin
            adjustWire.wset(powerTable[6]);      
         end
       else if(power < powerThresholdLow) // only need a small change
         begin
            adjustWire.wset(powerTable[5]);      
         end
       else if(power > powerThresholdHigh * 8) // need to amp down power for 4.5dB
         begin
            adjustWire.wset(powerTable[0]);      
         end
       else if(power > powerThresholdHigh * 4) // need to amp down power for 3dB
         begin
            adjustWire.wset(powerTable[1]);      
         end
       else if(power > powerThresholdHigh * 2) // need to amp down power for 1.5dB
         begin
            adjustWire.wset(powerTable[2]);      
         end
       else if(power > powerThresholdHigh * 2 - powerThresholdHigh * 0.5) // need to amp down power for 0.88dB
         begin
            adjustWire.wset(powerTable[3]);      
         end
       else if(power > powerThresholdHigh) // only need a small change
         begin
            adjustWire.wset(powerTable[4]);      
         end
     endmethod
  endinterface

  interface Get response;  
    method ActionValue#(Int#(10)) get() if(adjustWire.wget() matches tagged Valid .value);
      return value;
    endmethod
  endinterface

endmodule









/* A better sweep rule
   rule handlePowerSweep(delay == 0 && calibrationMode == 0 && directGainControl == 0 && gainState == Sweeping);
    if(sweepUp) 
      begin
        if(rxGain == rxGainMin)
          begin
            sweepUp <= !sweepUp;
          end
        else
          begin
            rxGain <= (rxGain+16 > rxGainMin)?rxGainMin:rxGain + 16;
          end
      end
    else
      begin
        if(rxGain == rxGainMax)
          begin
            sweepUp <= !sweepUp;
          end
        else
          begin
            rxGain <= (rxGain-16 < rxGainMax)?rxGainMax:rxGain - 16;
          end
      end
   endrule
*/


