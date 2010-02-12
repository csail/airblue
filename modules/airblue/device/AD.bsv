import Clocks::*;
import GetPut::*;
import Complex::*;
import FIFO::*;
import CBus::*;
import FIFOF::*;
import FixedPoint::*;

// import FPGAParameters::*;
// import DataTypes::*;
// import FPComplex::*;
// import ProtocolParameters::*;
// import Scaler::*;
// import Interfaces::*;
// import Synchronizer::*;
// import MACPhyParameters::*;

// import BRAMFIFO::*;
// import FIFOUtility::*;
// import CBusUtils::*;
// import Averager::*;
// import StreamCaptureFIFO::*;
// import TriggeredStreamCaptureFIFOF::*;
// import Min::*;
// import Debug::*;

// this file wraps the ADC and DAC control chips.  Mostly, we're registering logic.
// Local includes
`include "asim/provides/debug_utils.bsh"
`include "asim/provides/stream_capture_fifo.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_synchronizer.bsh" // try to get rid of, it only need to know some type exported by the synchronizer for now
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/fifo_utils.bsh"
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/stat_min.bsh"
`include "asim/provides/stat_avaerager.bsh"


Bool adDebug = True;

interface DACWires;
 (* always_ready, always_enabled, prefix="", result="dac_gain_ctrl" *) 
  method Bit#(1) dacGainCtrl();
 (* always_ready, always_enabled, prefix="", result="dac_pwd" *) 
  method Bit#(1) dacPwd();
 (* always_ready, always_enabled, prefix="", result="dac_mode" *) 
  method Bit#(1) dacMode();
 (* always_ready, always_enabled, prefix="", result="dac_mode_select" *) 
  method Bit#(1) dacModeSelect();
 (* always_ready, always_enabled, prefix="", result="dac_imag" *) 
  method Bit#(10) dacIPart();
 (* always_ready, always_enabled, prefix="", result="dac_real" *) 
  method Bit#(10) dacRPart();
 interface Clock dacWrt1; 
 interface Clock dacWrt2; 
 interface Clock dacClk1; 
 interface Clock dacClk2; 
endinterface

interface DAC;
  interface Put#(DACMesg#(TXFPIPrec,TXFPFPrec)) dataOut;
  interface DACWires dacWires;
  interface Put#(TXVector) txStart;
  method Action agcGainSet(Bit#(10) gain);
  method ActionValue#(Bit#(0)) txComplete();
endinterface 

interface ADCWires;
  (* always_ready, always_enabled, prefix="", result="adc_dcs" *) 
  method Bit#(1) adcDCS();
  (* always_ready, always_enabled, prefix="", result="adc_dfs" *) 
  method Bit#(1) adcDFS();
  (* always_ready, always_enabled, prefix="", result="adc_mux_sel" *) 
  method Bit#(1) adcMuxSel();
  (* always_ready, always_enabled, prefix="", result="adc_oen" *) 
  method Bit#(1) adcOEN();
  (* always_ready, always_enabled, prefix="", result="adc_pwd" *) 
  method Bit#(1) adcPWD();
  (* always_ready, always_enabled, prefix="", result="adc_ref_sel" *) 
  method Bit#(1) adcRefSel();
 (* always_ready, always_enabled, prefix="", result="adc_real" *) 
  method Action adcRPart(Bit#(10) rin);
 (* always_ready, always_enabled, prefix="", result="adc_imag" *) 
  method Action adcIPart(Bit#(10) iin);
  interface Clock adcClk;
endinterface

interface ADC;
  interface Get#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) dataIn;
  interface Put#(Synchronizer::ControlType) synchronizerStateUpdate;
  interface ADCWires adcWires;
  method ActionValue#(FPComplex#(ADCIPart,ADCFPart)) agcSampleBypass();
  method Action triggerCapture();
endinterface 

function Integer divCeil(Integer a, Integer b);
   return (a+b-1)/b;
endfunction

// These functions are used to determine the length of a packet
// refactor at some point
// function Integer bitsPerSymbol(Rate rate);
//       // data bis per ofdm symbol 
//    return case (rate)
// 		      R0: 12;
// 		      R1: 18;
// 		      R2: 24;
// 		      R3: 36;
// 		      R4: 48;
// 		      R5: 72;
// 		      R6: 96;
// 		      R7: 108;
//           endcase;
// endfunction

// 80 chips / symbol  
// 320 to start

// should we disable sometimes?
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkADC#(Clock basebandClock, Reset basebandReset) (ADC);
  Clock clock <- exposeCurrentClock;
  SyncFIFOIfc#(DACMesg#(RXFPIPrec,RXFPFPrec)) infifo <- mkSyncFIFOFromCC(16,basebandClock);
  //SyncFIFOIfc#(DACMesg#(RXFPIPrec,RXFPFPrec)) infifoStream <- mkSyncFIFOFromCC(16,basebandClock);
  FIFO#(FPComplex#(RXFPIPrec,RXFPFPrec)) bramfifo <- mkSizedFIFO_BRAM(2048,clocked_by basebandClock, reset_by basebandReset); // sounds reasonable.
  FIFOF#(DACMesg#(RXFPIPrec,RXFPFPrec)) streamfifo <- mkStreamCaptureFIFOF(32768,clocked_by basebandClock, reset_by basebandReset);
  TriggeredStreamCaptureFIFOF#(DACMesg#(RXFPIPrec,RXFPFPrec)) triggeredstreamfifo <- mkTriggeredStreamCaptureFIFOF(16384,clocked_by basebandClock, reset_by basebandReset);
  RWire#(DACMesg#(RXFPIPrec,RXFPFPrec)) scaledwire <- mkRWire(clocked_by basebandClock, reset_by basebandReset);
  RWire#(Synchronizer::ControlType) syncWire <-mkRWire(clocked_by basebandClock, reset_by basebandReset);
  PulseWire triggerCaptureWire <-mkPulseWire(clocked_by basebandClock, reset_by basebandReset);
  Scaler#(RXFPIPrec,RXFPFPrec) scaler <- mkScaler(valueof(AddrRXScaleFactor),clocked_by basebandClock, reset_by basebandReset);

  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrADCDCS = CRAddr{a: fromInteger(valueof(AddrADCDCS)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrADCDFS = CRAddr{a: fromInteger(valueof(AddrADCDFS)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrADCMuxSel = CRAddr{a: fromInteger(valueof(AddrADCMuxSel)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrADCRefSel = CRAddr{a: fromInteger(valueof(AddrADCRefSel)) , o: 0};
  // probably want a more general solution here
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrADCSampleCountLow = CRAddr{a: fromInteger(valueof(AddrADCSampleCountLow)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrADCSampleCountHigh = CRAddr{a: fromInteger(valueof(AddrADCSampleCountHigh)) , o: 0};
 CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrADCDropCounter = CRAddr{a: fromInteger(valueof(AddrADCDropCounter)) , o: 0};

  // These defaults were determined by an analysis of the data sheet
  Reg#(Bit#(1)) adcDCS <- mkCBRegRW(addrADCDCS,1,clocked_by basebandClock, reset_by basebandReset); 
  Reg#(Bit#(1)) adcDFS <- mkCBRegRW(addrADCDFS,0,clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(32)) adcDropCounter <- mkCBRegR(addrADCDropCounter,0,clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(1)) adcMuxSel <- mkCBRegRW(addrADCMuxSel,1,clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(1)) adcOEN <- mkReg(0);
  Reg#(Bit#(1)) adcPWD <- mkReg(0);
  Reg#(Bit#(1)) adcRefSel <- mkCBRegRW(addrADCRefSel,1,clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(10)) adcRPart <- mkReg({1'b1,0});
  Reg#(Bit#(10)) adcIPart <- mkReg({1'b1,0});
  Reg#(Bool) seenFirst <- mkReg(False,clocked_by basebandClock, reset_by basebandReset); 
  PulseWire adcRead <- mkPulseWire(clocked_by basebandClock, reset_by basebandReset);


  mkCBusGet(valueof(AddrADCStreamFifoOffset),fifoToGet(fifofToFifo(streamfifo)),clocked_by basebandClock, reset_by basebandReset);
  mkCBusGet(valueof(AddrADCTriggeredStreamFifoOffset),fifoToGet(fifofToFifo(triggeredstreamfifo.fifof)),clocked_by basebandClock, reset_by basebandReset);
  


  FPComplex#(ADCIPart,ADCFPart) sample;
  sample.img = unpack({~adcIPart[9],truncate(adcIPart)});
  sample.rel = unpack({~adcRPart[9],truncate(adcRPart)});

  rule rawEnq;
    infifo.enq(fpcmplxSignExtend(sample));
  endrule

  rule scale;
   $display("ADC post-infifo");
    infifo.deq;
    scaler.in.put(infifo.first);
  endrule

  rule grabScale;
    $display("ADC post-scaler");
    let result <- scaler.out.get;
    scaledwire.wset(result);
    seenFirst <= True;
  endrule 

  rule dataDropCheck(scaledwire.wget matches tagged Valid .data &&& !adcRead);
    adcDropCounter <= adcDropCounter + 1; 
    $display("ADC Failed to read in data");
    $finish;
  endrule


  rule bramEnq(scaledwire.wget matches tagged Valid .data);
     bramfifo.enq(data);
     adcRead.send;
  endrule

  rule trigStreamEnq(scaledwire.wget matches tagged Valid .data);
    triggeredstreamfifo.fifof.enq(data);
  endrule

  rule driveTrigger(triggerCaptureWire);
    triggeredstreamfifo.trigger();
  endrule

  rule streamEnq(scaledwire.wget matches tagged Valid .data);
    streamfifo.enq(data);
  endrule

  method Action triggerCapture();
    triggerCaptureWire.send;
  endmethod

  interface Put synchronizerStateUpdate;
    method Action put(Synchronizer::ControlType ctrl);
      syncWire.wset(ctrl);
    endmethod
  endinterface

  interface Get dataIn;
    method ActionValue#(DACMesg#(RXFPIPrec,RXFPFPrec)) get();
      bramfifo.deq;
      $display("ADC get");
      return bramfifo.first;
    endmethod
  endinterface

  interface ADCWires adcWires;
    method adcDCS = adcDCS._read;
    method adcDFS = adcDFS._read;
    method adcMuxSel = adcMuxSel._read;
    method adcOEN = adcOEN._read;
    method adcPWD = adcPWD._read;
    method adcRefSel = adcRefSel._read;
    method adcRPart = adcRPart._write;
    method adcIPart = adcIPart._write;
    interface adcClk = clock;
  endinterface 

  method ActionValue#(FPComplex#(ADCIPart,ADCFPart)) agcSampleBypass();
    return sample;
  endmethod
 
endmodule


module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkDAC#(Clock basebandClock, Reset basebandReset) (DAC);
  Clock clock <- exposeCurrentClock;
  ClockDividerIfc invClock <- mkClockInverter;  
  SyncFIFOIfc#(DACMesg#(TXFPIPrec,TXFPFPrec)) infifo <- mkSyncFIFOToCC(16,basebandClock,basebandReset);
  SyncBitIfc#(Bool) txENrf <- mkSyncBitToCC(basebandClock, basebandReset);

   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrDACGain = CRAddr{a: fromInteger(valueof(AddrDACGain)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrDACMode = CRAddr{a: fromInteger(valueof(AddrDACMode)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRX_PE = CRAddr{a: fromInteger(valueof(AddrRX_PE)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrDCCCalibration = CRAddr{a: fromInteger(valueof(AddrDCCCalibration)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrTXtoRXGainRouteDelayCycles = CRAddr{a: fromInteger(valueof(AddrTXtoRXGainRouteDelayCycles)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXtoTXGainRouteDelayCycles = CRAddr{a: fromInteger(valueof(AddrRXtoTXGainRouteDelayCycles)) , o: 0};

  // XXX put these somewhere


  // Find the defaults
  // Register the world
  Reg#(Bit#(1)) dacGainCtrl   <- mkCBRegRW(addrDACGain,1, clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(1)) dacPwd        <- mkReg(0);
  Reg#(Bit#(1)) dacMode       <- mkCBRegRW(addrDACMode,1, clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(10)) dacIPart     <- mkReg({1'b1,0});
  Reg#(Bit#(10)) dacRPart     <- mkReg({1'b1,0});
  Reg#(Bit#(1))  dacModeSelect <- mkReg(0); 
  Reg#(Bit#(8))  txToRxGainRouteDelayCycles <- mkCBRegRW(addrTXtoRXGainRouteDelayCycles, fromInteger(valueOf(TXtoRXGainRouteDelayCycles)), clocked_by basebandClock, reset_by basebandReset); 
  Reg#(Bit#(8))  rxToTxGainRouteDelayCycles <- mkCBRegRW(addrRXtoTXGainRouteDelayCycles, fromInteger(valueOf(RXtoTXGainRouteDelayCycles)), clocked_by basebandClock, reset_by basebandReset); 

  Reg#(Bit#(10)) dacRXGainRF <- mkSyncRegToCC(0,basebandClock, basebandReset);
  Min#(Bit#(32)) minSampleCount <- mkMin(clocked_by basebandClock, reset_by basebandReset);
  Averager#(Bit#(32)) avgSampleCount <- mkAverager(16,clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(32)) sampleCount <- mkReg(0,clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(32)) sampleCountSlow <- mkReg(0);
  PulseWire sampleOutput <- mkPulseWire(clocked_by basebandClock, reset_by basebandReset);
  PulseWire sampleOutputRF <- mkPulseWire();

  mkCBusWideRegR(valueof(AddrADCSampleMin), minSampleCount.min,
                 clocked_by basebandClock, reset_by basebandReset);
  mkCBusWideRegR(valueof(AddrADCSampleAvg), avgSampleCount.average);
  Reg#(Bit#(1)) calibrationMode <- mkCBRegRW(addrDCCCalibration,0,clocked_by basebandClock, reset_by basebandReset);
  Scaler#(TXFPIPrec,TXFPFPrec) scaler <- mkScaler(valueof(AddrTXScaleFactor),clocked_by basebandClock, reset_by basebandReset);
  FIFO#(FPComplex#(TXFPIPrec,TXFPFPrec)) scalerFIFO <- mkFIFO(clocked_by basebandClock, reset_by basebandReset);

  // Regs related to tracking t packet
  Reg#(Bit#(17)) length <- mkReg(0,clocked_by basebandClock, reset_by basebandReset); 
  Reg#(Bit#(7))  chipCount <- mkReg(0,clocked_by basebandClock, reset_by basebandReset);
  Reg#(Bit#(16))  preambleCount <- mkReg(0,clocked_by basebandClock, reset_by basebandReset);
  // a fifo here may be over kill we might be able to remove at some point.
  FIFO#(Bit#(0)) completionFIFO <- mkFIFO(clocked_by basebandClock, reset_by basebandReset); 
  // Should look around to see if we can pull out/share code.
  FIFOF#(TXVector) txFIFO <- mkFIFOF(clocked_by basebandClock, reset_by basebandReset); // 4 is probably large enough   
  Reg#(Bit#(8)) txTimeoutDelay <- mkReg(0,clocked_by basebandClock, reset_by basebandReset);  // used to manage events on tx -> rx transition
  Reg#(Bit#(8)) rxTimeoutDelay <- mkReg(0,clocked_by basebandClock, reset_by basebandReset); // used to manage events on rx -> tx transition
  Reg#(Bit#(32)) slowTicks <- mkReg(0);
  Reg#(Bit#(32)) fastTicks <- mkReg(0, clocked_by basebandClock, reset_by basebandReset);

  rule tickSlow;
    slowTicks <= slowTicks + 1;
  endrule 
   
  rule tickFast;
    fastTicks <= fastTicks + 1;
  endrule
  //XXX may need some better support for calibration mode - gct currently prevents tx start when calibrating

  rule setTXDelay(txFIFO.notEmpty && calibrationMode == 0);
    txTimeoutDelay <= 0;
  endrule 

  rule tickDelayTX((!txFIFO.notEmpty || calibrationMode == 1) && (txTimeoutDelay != ~0));
    txTimeoutDelay <= txTimeoutDelay + 1;
  endrule  

  rule setRXDelay(!txFIFO.notEmpty || calibrationMode == 1);
    rxTimeoutDelay <= 0;
  endrule 

  rule tickDelayRX((txFIFO.notEmpty && calibrationMode == 0) && (rxTimeoutDelay != ~0));
    rxTimeoutDelay <= rxTimeoutDelay + 1;
  endrule  

  rule displayCounts;
    debug(adDebug,$display("AD: rxTimeout %d txTimeout %d",rxTimeoutDelay,txTimeoutDelay));
   $display("AD: txfifo is %s", (txFIFO.notEmpty)?"Not Empty":"Empty");
  endrule

  // We are making a latency assumption here.
  // This needs closer attention
  // txEn == 1, drive output for tx
  // txEn == 0, drive output for rx
  rule setTXENrf;
    txENrf.send((rxTimeoutDelay > rxToTxGainRouteDelayCycles) || 
                (txTimeoutDelay < txToRxGainRouteDelayCycles));
  endrule


  //
  // output 1 means tx 0 means agc...
  rule setDACModeSelect;
    dacModeSelect <= (txENrf.read)?1:0;
  endrule

  
  rule sendGain(!txENrf.read);
    dacIPart <= dacRXGainRF;
    dacRPart <= dacRXGainRF;
    $display("AD driving gain wires");
  endrule 
  
  // Need to have some state so we don't miss a packet start

  rule beginPacket(length == 0 && preambleCount == 0);
     // header + extra symbols - length is in bits.
     // length + 2 for service
     // 6 bits for the tail 
     // we will need some padding
//     Integer header_sz = valueOf(HeaderSz);
     // double preamble_sz if has trailer
//     Integer preamble_sz_int = 320 + divCeil(header_sz,bitsPerSymbol(R0))*80;
//     Bit#(16) preamble_sz = txFIFO.first.header.has_trailer ? fromInteger(preamble_sz_int*2) : fromInteger(preamble_sz_int);
     Bit#(16) preamble_sz = getPreambleCount(txFIFO.first.header.has_trailer);
     Bit#(17) bit_length  = getBitLength(txFIFO.first.header.length);
     debug(adDebug,$display("AD: begin packet, length = %d",  zeroExtend(preamble_sz) + bit_length));
     preambleCount <= preamble_sz;  // header is 24 bits and always sent as basic rate
     length <= bit_length; // bit length
  endrule  


  rule sampleTick;
    if(sampleOutput)
      begin
        sampleCount <= sampleCount + 1;
      end
    else if(sampleCount != 0)
      begin
        $display("AD Sample tick reset: %d", sampleCount);
        sampleCount <= 0;
        avgSampleCount.inputSample(sampleCount);
        minSampleCount.inputSample(sampleCount);
      end
  endrule

  rule sampleTickSlow;
    if(sampleOutputRF)
      begin
        sampleCountSlow <= sampleCountSlow + 1;
      end
    else if(sampleCountSlow != 0)
      begin
        $display("AD Sample tick slow reset: %d at %d", sampleCountSlow,slowTicks);
        sampleCountSlow <= 0;
      end
  endrule

  rule fifoStatus;
   $display("AD: infifo is %s", (infifo.notEmpty)?"Not Empty":"Empty");
   $display("AD: txEN is %s", (txENrf.read)?"Not Empty":"Empty");
  endrule

  // drive zero while idle
  rule setZeros(!infifo.notEmpty && txENrf.read);
    dacIPart <= {1'b1,0}; 
    dacRPart <= {1'b1,0}; 
    $display("AD zeroing dac wires"); 
  endrule

  rule dataLeftovers(infifo.notEmpty && !txENrf.read);
     $display("AD is dropping data");
     $finish; 
  endrule


  rule driveDAC(txENrf.read && infifo.notEmpty);
    infifo.deq;
    $display("AD driving dac wires");
    sampleOutputRF.send;
    FPComplex#(DACIPart,DACFPart) sample = fpcmplxTruncate(infifo.first);
    Bit#(10) iPart = {~(pack(sample.img)[9]) ,truncate(pack(sample.img))};  
    Bit#(10) rPart = {~(pack(sample.rel)[9]) ,truncate(pack(sample.rel))};  
    dacIPart <= iPart; 
    dacRPart <= rPart; 
  endrule

  
  rule inFifo;
   let data <- scaler.out.get;
   sampleOutput.send;
   infifo.enq(data);
   scalerFIFO.deq;
  endrule

  rule driveScale;
    scaler.in.put(scalerFIFO.first);
  endrule

  // we must be ready to rx a packet.
  interface Put dataOut;
     method Action put(DACMesg#(TXFPIPrec,TXFPFPrec) data); //if(length != 0);

       debug(adDebug,$display("AD: calling data: preamble: %d length: %d chipCount: %d, rate: %d bytes: %d",preambleCount,length,chipCount,txFIFO.first.header.rate,txFIFO.first.header.length));
       scalerFIFO.enq(data);
       if(preambleCount > 0) 
         begin
           preambleCount <= preambleCount - 1;
         end
       else if(chipCount + 1 == fromInteger(valueof(SymbolLen)))
         begin
           chipCount <= 0;
           debug(adDebug,$display("AD: setting down length"));
           // we may have pad bits.  the last subtraction may not equal zero
           if(length <= fromInteger(bitsPerSymbol(txFIFO.first.header.rate)))
             begin
               // at this point we should send the deq pulse
               txFIFO.deq;
               completionFIFO.enq(0);
               length <= 0; 
               debug(adDebug,$display("AD: length done @ $d",fastTicks));
             end   
           else
             begin
              debug(adDebug,$display("AD: substraction"));
              length <= length - fromInteger(bitsPerSymbol(txFIFO.first.header.rate)); 
            end
        end
      else
        begin
         chipCount <= chipCount + 1;
        end
     endmethod
  endinterface



  interface DACWires dacWires; 
    method dacGainCtrl = dacGainCtrl._read;
    method dacPwd = dacPwd._read;
    method dacMode = dacMode._read;
    method dacModeSelect = dacModeSelect._read;
    method dacIPart = dacIPart._read;
    method dacRPart = dacRPart._read;

    interface dacWrt1 = invClock.slowClock; 
    interface dacWrt2 = invClock.slowClock; 
    interface dacClk1 = invClock.slowClock; 
    interface dacClk2 = invClock.slowClock; 
  endinterface

  interface Put txStart;
    method Action put(TXVector txvec);
      txFIFO.enq(txvec);
    endmethod
  endinterface

  method Action agcGainSet(Bit#(10) gain);
    dacRXGainRF <= gain;
  endmethod

  method ActionValue#(Bit#(0)) txComplete();
    completionFIFO.deq;
    return 0;
  endmethod
endmodule