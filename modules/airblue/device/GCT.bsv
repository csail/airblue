import GetPut::*;
import ClientServer::*;
import CBus::*;
import FIFOF::*;

// import Synchronizer::*;
// import FPGAParameters::*;
// import MACPhyParameters::*;

// import SPIMaster::*;
// import Debug::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/debug_utils.bsh"
`include "asim/provides/spi.bsh"

// These are time constants for enabling/disabling the rx/tx

Bool gctDebug = True;

typedef 1   SPISlaveCount;
typedef 5   SPIAddrSz;
typedef 16  SPIDataSz;
typedef Bit#(TAdd#(1,TAdd#(SPIAddrSz,SPIDataSz))) SPIRawBits;

// should define a type for the SPI  probably need to pack it myself.

interface GCTWires;
 (* always_ready, always_enabled, prefix="", result="gct_tx_pe" *)
 method Bit#(1) txPE();   
 (* always_ready, always_enabled, prefix="", result="gct_rx_pe" *) 
 method Bit#(1) rxPE();
 (* always_ready, always_enabled, prefix="", result="gct_rx_tx_switch" *)
 method Bit#(1) rxTxSwitch();   
 (* always_ready, always_enabled, prefix="", result="gct_rx_tx_switch_n" *)
 method Bit#(1) rxTxSwitchN();   
 (* always_ready, always_enabled, prefix="", result="gct_ghold" *) 
 method Bit#(1) gHold();
 (* always_ready, always_enabled, prefix="", result="gct_rx_rfg1" *) 
 method Bit#(1) rxRFG1();
 (* always_ready, always_enabled, prefix="", result="gct_rx_rfg2" *) 
 method Bit#(1) rxRFG2();
 method Bit#(1) pa_EN();
endinterface

interface GCT;
  interface Put#(SPIRawBits) spiCommand;
  interface GCTWires gctWires;      
  interface SPIMasterWires#(SPISlaveCount) spiWires;
  interface Put#(ControlType) synchronizerStateUpdate;
  interface Put#(RXExternalFeedback) packetFeedback;
  interface Put#(TXVector) txStart;
  interface Put#(Bit#(0)) txComplete; // This Bit 0 is ugly.
  interface Get#(Bool) rxBusy;
  interface Get#(Bool) txBusy;
endinterface

typedef enum {
  Held,
  Packet, // Waiting for packet decode
  UnHeld
} GHoldState deriving (Bits,Eq);


typedef enum {
  Idle = 0,
  ShortSync = 1,
  LongSync = 2,
  Timeout = 3,
  Header = 4, 
  Abort = 5,
  Data = 6
} PipeState deriving (Bits,Eq);

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkGCT (GCT)
  provisos(Add#(1,xxx,AvalonDataWidth));
  
  Reg#(Bool) initialized <- mkReg(False);

  /* These regs drive the grt digital signals. */
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrDCCCalibration = CRAddr{a: fromInteger(valueof(AddrDCCCalibration)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXRFG1 = CRAddr{a: fromInteger(valueof(AddrRXRFG1)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXRFG2 = CRAddr{a: fromInteger(valueof(AddrRXRFG2)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrPA_EN = CRAddr{a: fromInteger(valueof(AddrPA_EN)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrTX = CRAddr{a: fromInteger(valueof(AddrTX_PE)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRX = CRAddr{a: fromInteger(valueof(AddrRX_PE)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrTXVectorsReceived = CRAddr{a: fromInteger(valueof(AddrTXVectorsReceived)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrTXVectorsProcessed = CRAddr{a: fromInteger(valueof(AddrTXVectorsProcessed)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrGCTPipelineState = CRAddr{a: fromInteger(valueof(AddrGCTPipelineState)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrTXtoRXDelayCycles = CRAddr{a: fromInteger(valueof(AddrTXtoRXDelayCycles)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXtoTXDelayCycles = CRAddr{a: fromInteger(valueof(AddrRXtoTXDelayCycles)) , o: 0};
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrTXtoRXGHoldDelayCycles = CRAddr{a: fromInteger(valueof(AddrTXtoRXGHoldDelayCycles)) , o: 0};


  Reg#(Bit#(1)) txPE <- mkCBRegR(addrTX, 0);
  Reg#(Bit#(1)) rxPE <- mkCBRegR(addrRX, 0);
  Reg#(Bit#(1)) calibrationMode <- mkCBRegRW(addrDCCCalibration,0);
  Reg#(Bit#(1)) gHold <- mkReg(1);
  Reg#(GHoldState) gHoldState <- mkReg(UnHeld);
  Reg#(Bit#(1)) rxRFG1 <- mkCBRegRW(addrRXRFG1,1);
  Reg#(Bit#(1)) rxRFG2 <- mkCBRegRW(addrRXRFG2,1);
  Reg#(Bit#(1)) pa_EN <- mkCBRegR(addrPA_EN,1);
  Reg#(Bit#(8)) txTimeoutDelay <- mkReg(0); // use this to control rx/tx
  Reg#(Bit#(8)) rxTimeoutDelay <- mkReg(0); // use this to control rx/tx
  Reg#(Bit#(32)) txVectorsReceived <- mkCBRegRW(addrTXVectorsReceived,0);
  Reg#(Bit#(32)) txVectorsProcessed <- mkCBRegRW(addrTXVectorsProcessed,0);
  Reg#(Bit#(32)) cycleCounter <- mkReg(0);
  Reg#(PipeState) pipelineState <- mkCBRegR(addrGCTPipelineState,Idle);
  Reg#(Bit#(8))  txToRxDelayCycles <- mkCBRegRW(addrTXtoRXDelayCycles, fromInteger(valueOf(TXtoRXDelayCycles))); 
  Reg#(Bit#(8))  rxToTxDelayCycles <- mkCBRegRW(addrRXtoTXDelayCycles, fromInteger(valueOf(RXtoTXDelayCycles))); 
  Reg#(Bit#(8))  txToRxGHoldDelayCycles <- mkCBRegRW(addrTXtoRXGHoldDelayCycles, fromInteger(valueOf(TXtoRXGHoldDelayCycles))); 
   
  FIFOF#(TXVector) txFIFO <- mkSizedFIFOF(4); // 4 is probably large enough 

  SPIMaster#(SPISlaveCount, SPIRawBits) spiMaster <- mkSPIMaster(8);

  /* state for dealing with ghold */
  Reg#(Bit#(20)) gHoldTimeout <- mkReg(0);
  RWire#(ControlType) syncWire <-mkRWire;
  RWire#(RXExternalFeedback) feedbackWire <-mkRWire;

  rule tickCounter;
    cycleCounter <= cycleCounter + 1;
  endrule

  rule resetRxTimeoutDelay(!txFIFO.notEmpty || calibrationMode == 1);
    rxTimeoutDelay <= 0;
  endrule

  rule resetTxTimeoutDelay(txFIFO.notEmpty && calibrationMode == 0);
    txTimeoutDelay <= 0;
  endrule

  rule tickRxTimeoutDelay(calibrationMode == 0 && txFIFO.notEmpty && rxTimeoutDelay != ~0);
    rxTimeoutDelay <= rxTimeoutDelay + 1;
  endrule 

  rule tickTxTimeoutDelay((!txFIFO.notEmpty || calibrationMode == 1) && txTimeoutDelay != ~0);
    txTimeoutDelay <= txTimeoutDelay + 1;
  endrule

 
  // Really need to deal with calibration mode at some point.
  rule propagateRX(txTimeoutDelay >= txToRxDelayCycles && calibrationMode == 0);
    $display("Enabling RX");
    rxPE <= 1;
    txPE <= 0;
    pa_EN <= 1; //pa+EN == 1 to kill antenna gain
  endrule

  rule propagateTX(calibrationMode == 0 && rxTimeoutDelay >= rxToTxDelayCycles);  // check rxTimeout for the ghold
    $display("Enabling TX");
    txPE <= 1;
    rxPE <= 0;
    pa_EN <= 0;
  endrule

  // We still should wait for the shift here.
  rule setCalibration (calibrationMode == 1 && rxTimeoutDelay >= rxToTxDelayCycles);
    gHoldState <= UnHeld; // kicks us out of waiting for a packet
    gHold <= 1;
    rxPE <= 1;
    txPE <= 0;
    pa_EN <= 1;
  endrule

  // need to suppress GHold during the packet processing...
  rule setGHold (calibrationMode == 0);
    // either rxPE is off or we are txing, or we are about to tx...
    // we need ghold to be low.
    if(txTimeoutDelay < txToRxGHoldDelayCycles) 
      begin
        $display("GCT: set gHold Low TX");
        gHoldState <= Held;
        gHold <= 0;
        gHoldTimeout <= ~0;
        pipelineState <= Idle;
      end
    else if(txTimeoutDelay == txToRxGHoldDelayCycles) // receiver on, drop ghold & enter normal behavior
      begin
        $display("GCT: set gHold High TX");
        gHold <= 1;
        gHoldState <= UnHeld;
        gHoldTimeout <= ~0;
        pipelineState <= Idle;
      end
    else if(feedbackWire.wget matches tagged Valid .status)
      begin
        case(status)
          LongSync: 
            begin
              gHoldState <= Packet;
              gHold <= 0;
              gHoldTimeout <= ~0;
              pipelineState <= Header;
            end
          HeaderDecoded:  
            begin
              $display("GCT: HeaderDecoded @ %d", cycleCounter);
              gHoldTimeout <= ~0;
              gHold <= 0;
              gHoldState <= Packet;
              pipelineState <= Data;
            end 
          DataComplete:
            begin
               $display("GCT: DataComplete @ %d", cycleCounter);
               gHold <= 1;
               gHoldTimeout <= ~0;
               gHoldState <= UnHeld;
//               if (pipelineState != LongSync || pipelineState != ShortSync) // probably a trailer if sync is detected slig
               pipelineState <= Idle;
            end
          Abort:
            begin
              $display("GCT: Abort @ %d", cycleCounter);
              gHold <= 1;
              gHoldTimeout <= ~0;
              gHoldState <= UnHeld;
              pipelineState <= Abort;
            end
        endcase
      end
    else if(syncWire.wget matches tagged Valid .syncState &&& gHoldState != Packet)
      begin
         case(syncState)
           GHoldStart: begin
                         $display("GCT: set gHold Low");
                         gHold <= 0;
                         gHoldTimeout <= ~0;
                         pipelineState <= LongSync;
                       end 
           GainStart: begin
                        $display("GCT: set gHold High");
                        gHold <= 1;
                        gHoldTimeout <= ~0;  
                        pipelineState <= ShortSync;
                      end
           TimeOut: begin
                      $display("GCT: set gHold High");
                      gHold <= 1;
                      gHoldTimeout <= ~0;
                      pipelineState <= Idle;
                    end   
        endcase
      end      
    else  // this should happen only if we get really stuck
      begin
        if(gHoldTimeout > 0)
          begin
            gHoldTimeout <= gHoldTimeout - 1;
          end
        else if(gHoldState != Packet)
          begin
           gHoldState <= UnHeld;
           gHold <= 1;
         end
      end
  endrule

  rule clearSPIMaster;
    let data <- spiMaster.server.response.get;
  endrule

  interface Put spiCommand;
    method Action put(SPIRawBits command);
      spiMaster.server.request.put(SPIMasterRequest{slave:0, data:command});
    endmethod
  endinterface

  interface spiWires = spiMaster.wires; 
  interface GCTWires gctWires;
    method txPE = txPE._read;   
    method rxPE = rxPE._read;
    method rxTxSwitch = txPE._read | calibrationMode;   // Shut off during calibration
    method rxTxSwitchN = ~txPE._read & ~calibrationMode;      
    method gHold = gHold._read;
    method rxRFG1 = rxRFG1._read;
    method rxRFG2 = rxRFG2._read;
    method pa_EN = pa_EN._read;
  endinterface

  // We chould probably only care about this if we are rxing
  // otherwise we should drop this crap
  interface Put synchronizerStateUpdate;
    method Action put(ControlType ctrl);
      
      syncWire.wset(ctrl);
    endmethod
  endinterface


  // no tx start when calibrating
  interface Put txStart;
    method Action put(TXVector txvec) if(calibrationMode == 0); // No conflict with counting rule >
      txFIFO.enq(txvec);
      txVectorsReceived <= txVectorsReceived + 1;
      debug(gctDebug,$display("GCT txFIFO enq"));  
    endmethod
  endinterface

  interface Put txComplete; // This Bit 0 is ugly.
    method Action put(Bit#(0) in);
      txVectorsProcessed <= txVectorsProcessed + 1;
      debug(gctDebug,$display("GCT txFIFO deq"));  
      txFIFO.deq; 
    endmethod
  endinterface

  interface Put packetFeedback;
    method Action put(RXExternalFeedback feedback);
      feedbackWire.wset(feedback);      
    endmethod
  endinterface

  // XXX need to check RX state here as well....
  // this name is misleading...
  interface Get txBusy;
    method ActionValue#(Bool) get();
      return  txPE == 1;      
    endmethod
  endinterface 

  interface Get rxBusy; // Is this correct? We may want to ignore longSync/shortSync 
    method ActionValue#(Bool) get();
      return  pipelineState == LongSync || pipelineState == Data || pipelineState == Header;//pipelineState != Idle;      
    endmethod
  endinterface 
endmodule
