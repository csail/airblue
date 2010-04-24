
import ClientServer::*;
import Vector::*;
import Clocks::*;
import Complex::*;
import FixedPoint::*;
import GetPut::*;
import StmtFSM::*;
import CBus::*;

`include "asim/provides/fpga_components.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/analog_digital.bsh"
`include "asim/provides/gain_control.bsh"
`include "asim/provides/rf_frontend.bsh"
`include "asim/provides/board_control.bsh"
`include "asim/provides/spi.bsh"

interface RF_WIRES;
  interface GCT_WIRES   gct_wires;
  interface DAC_WIRES   dac_wires;
  interface ADC_WIRES   adc_wires;
  interface AGC_WIRES   agc_wires;
  interface BOARD_WIRES board_wires;
endinterface

interface RF_DRIVER_MONAD;
  interface Put#(DACMesg#(TXFPIPrec,TXFPFPrec)) rfIn;
  interface Put#(TXVector) txStart;
  interface Put#(RXExternalFeedback) rxStateUpdate;
  interface Get#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) rfOut;
  interface Put#(SPIMasterRequest#(SPISlaveCount,SPIRawBits)) spiCommand;
endinterface

interface RF_DRIVER;
  interface Put#(DACMesg#(TXFPIPrec,TXFPFPrec)) rfIn;
  interface Put#(TXVector) txStart;
  interface Put#(RXExternalFeedback) rxStateUpdate;
  interface Get#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) rfOut;
  interface Put#(SPIMasterRequest#(SPISlaveCount,SPIRawBits)) spiCommand;
  interface CBus#(AvalonAddressWidth,AvalonDataWidth) busWires;
endinterface

// We need these to have some degree of backward compatibility with 
// existing CBus stuff
interface RF_DEVICE_MONAD;
  interface RF_WIRES wires;
  interface RF_DRIVER_MONAD driver;
endinterface

interface RF_DEVICE;
  interface RF_WIRES wires;
  interface RF_DRIVER driver;
endinterface


module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkRFDeviceMonad (RF_DEVICE_MONAD);

  //Assume for now that model clock and baseband clock are the same
  Clock basebandClock <- exposeCurrentClock;
  Reset basebandReset <- exposeCurrentReset;

  
  UserClock rf <- mkUserClock_PLL(`CRYSTAL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,20);

  // Instantiate the various device interface modules
 
  GCT_DEVICE  gct <- mkGCT();
  DAC_DEVICE  dac <- mkDAC(basebandClock, basebandReset, clocked_by rf.clk, reset_by rf.rst);
  ADC_DEVICE  adc <- mkADC(basebandClock, basebandReset, clocked_by rf.clk, reset_by rf.rst);
  AGC_DEVICE  agc <- mkAGC;
  BOARD_DEVICE board <- mkBoard; 

  rule sendGainToADC;
    dac.dac_driver.agcGainSet(agc.agc_driver.outputGain);
  endrule


  interface RF_DRIVER_MONAD driver;
    interface rfOut = adc.adc_driver.dataIn();

    interface rfIn = dac.dac_driver.dataOut();

    interface Put txStart;
      method Action put(TXVector txVec);
        gct.gct_driver.txStart.put(txVec);
        dac.dac_driver.txStart.put(txVec);
      endmethod
    endinterface

    interface Put rxStateUpdate;
      method Action put(RXExternalFeedback  feedback);
        agc.agc_driver.packetFeedback.put(feedback); 
        gct.gct_driver.packetFeedback.put(feedback);
      endmethod
    endinterface

    interface spiCommand = gct.gct_driver.spiCommand;

  endinterface


  interface RF_WIRES wires;
    interface gct_wires = gct.gct_wires;
    interface dac_wires = dac.dac_wires;
    interface adc_wires = adc.adc_wires;
    interface agc_wires = agc.agc_wires;
    interface board_wires = board.board_wires;
  endinterface

endmodule

// We need a module to insert reset synchronizers
module mkRFDevice (RF_DEVICE);
  
  // Build up CReg interface   
  let ifc <- liftModule(exposeCBusIFC(mkRFDeviceMonad()));

  interface wires = ifc.device_ifc.wires;

  interface RF_DRIVER driver;
    interface rfOut = ifc.device_ifc.driver.rfOut;
    interface txStart = ifc.device_ifc.driver.txStart;
    interface rxStateUpdate = ifc.device_ifc.driver.rxStateUpdate;
    interface rfIn = ifc.device_ifc.driver.rfIn;
    interface spiCommand = ifc.device_ifc.driver.spiCommand;
    interface busWires = ifc.cbus_ifc;
  endinterface
 
endmodule
