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

import Connectable::*;
import FIFO::*;
import GetPut::*;
import CBus::*;
import ModuleCollect::*;
import LFSR::*;
//import FIFOF::*;
import ClientServer::*;
//import GetPut::*;
import Clocks::*;
//import FixedPoint::*;

// import AvalonSlave::*;
// import AvalonCommon::*;
// import CBusUtils::*;
// import SPIMaster::*;
// //import Register::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import ProtocolParameters::*;
// import FPGAParameters::*;
// //import Receiver::*;
// //import Transmitter::*;
// //import TXController::*;
// //import RXController::*;
// import LibraryFunctions::*;
// //import FFTIFFT::*;
// import FPComplex::*;
// import Synchronizer::*;
// //import Unserializer::*;
// import FPComplex::*;
// import PacketGen::*;
// import PacketGenMAC::*;
// import WiFiReceiver::*;
// import WiFiTransmitter::*;
// import MACPhyParameters::*;

// import GCT::*;
// import AD::*;
// import Power::*;
// import AGC::*;
// import OutOfBand::*;

// import MAC::*;
// import MACDataTypes::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_mac_packet_gen.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_device.bsh"
`include "asim/provides/airblue_phy.bsh"
`include "asim/provides/airblue_mac.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/spi.bsh"
`include "asim/provides/c_bus_utils.bsh"

interface TransceiverASICWires;
  interface GCTWires gctWires;      
  interface ADCWires adcWires;
  interface DACWires dacWires;
  interface PowerCtrlWires powerCtrlWires;
  interface SPIMasterWires#(SPISlaveCount) spiWires;
  interface OutOfBandWires oobWires;
endinterface

interface TransceiverFPGA;
  interface GCTWires gctWires;      
  interface ADCWires adcWires;
  interface DACWires dacWires;
  interface SPIMasterWires#(SPISlaveCount) spiWires;
  interface PowerCtrlWires powerCtrlWires;
  interface AvalonSlaveWires#(AvalonAddressWidth,AvalonDataWidth) avalonWires;
  interface OutOfBandWires oobWires;
endinterface

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkTransceiverMACPacketGenFPGAMonad#(Clock viterbiClock, Reset viterbiReset, Clock rfClock, Reset rfReset) (TransceiverASICWires);
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;

   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerTimeOut = CRAddr{a: fromInteger(valueof(AddrSynchronizerTimeOut)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainHoldStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainHoldStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerLongSync = CRAddr{a: fromInteger(valueof(AddrSynchronizerLongSync)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXControlAbort = CRAddr{a: fromInteger(valueof(AddrRXControlAbort)) , o: 0};   
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrPhyPacketsRX = CRAddr{a: fromInteger(valueof(AddrPhyPacketsRX)) , o: 0};   
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACAbort = CRAddr{a: fromInteger(valueof(AddrMACAbort)) , o: 0};   

   // Fix me at some point
   Reg#(Bit#(32)) gainStart <- mkCBRegR(addrSynchronizerGainStart,0);
   Reg#(Bit#(32)) gholdStart<- mkCBRegR(addrSynchronizerGainHoldStart,0);
   Reg#(Bit#(32)) timeOut   <- mkCBRegR(addrSynchronizerTimeOut,0);
   Reg#(Bit#(32)) longSync <- mkCBRegR(addrSynchronizerLongSync,0);
   Reg#(Bit#(32)) abort <- mkCBRegR(addrRXControlAbort,0);
   Reg#(Bit#(32)) phyPacketsRX <- mkCBRegR(addrPhyPacketsRX,0);
   Reg#(Bit#(32)) macAbort <- mkCBRegR(addrMACAbort,0);
   

   Reg#(Bit#(64)) csmaIdle <- mkReg(0);
//   Empty  csmaIdleWrapper <- mkCBusWideRegR(valueof(AddrCyclesCSMAIdle),registerToReadOnly(csmaIdle));
   Reg#(Bit#(64)) csmaBusy <- mkReg(0);
//   Empty  csmaBusyWrapper <- mkCBusWideRegR(valueof(AddrCyclesCSMABusy),registerToReadOnly(csmaBusy));


   WiFiTransceiver transceiver <- mkTransceiver(viterbiClock, viterbiReset);
   MAC  mac <- mkMAC;
   GCT  gct <- mkGCT;
   DAC  dac <- mkDAC(clock, reset, clocked_by rfClock, reset_by rfReset);
   ADC  adc <- mkADC(clock, reset, clocked_by rfClock, reset_by rfReset);
   AGC  agc <- mkAGC;
   PowerCtrlWires powerCtrl <- mkPowerCtrl; 
   OutOfBand oob <- mkOutOfBand;   



   // hook up TX controlflow
   rule txCompleteNotify;
     let in <- dac.txComplete;
     gct.txComplete.put(in);
     mac.phy_txcomplete.put(in);
   endrule


   // hook the Synchronizer to feedback points  
   rule synchronizerFeedback;
     airblue_synchronizer::ControlType ctrl <- transceiver.receiver.synchronizerStateUpdate.get;
     gct.synchronizerStateUpdate.put(ctrl);
     agc.synchronizerStateUpdate.put(ctrl);
     case (ctrl) 
      GainStart:  gainStart <= gainStart + 1;
      GHoldStart: gholdStart <= gholdStart + 1;
      TimeOut:    timeOut <= timeOut + 1;
      LongSync:   longSync <= longSync + 1;
     endcase
   endrule
   

   // hook up the DAC/ADC
   mkConnection(transceiver.receiver.in,adc.dataIn);
   mkConnectionThroughput("CP->DAC",transceiver.transmitter.out,dac.dataOut);
   
   rule sendGainToADC;
     dac.agcGainSet(agc.outputGain);
   endrule

   rule sendPowToAGC;
     agc.inputPower(transceiver.receiver.synchronizerCoarPower);
   endrule
   


   // Hook mac to the transceiver
   mkConnection( transceiver.transmitter.txData, mac.phy_txdata.get);
   mkConnection( transceiver.receiver.outData, mac.phy_rxdata);
   mkConnection(mac.abortAck,transceiver.receiver.abortAck);
   
   rule connectAbortReq (True);
      let dont_care <- mac.abortReq.get;
      transceiver.receiver.abortReq;
   endrule
   
   rule countPhyPackets;
     let vec <- transceiver.receiver.outRXVector.get;
     mac.phy_rxstart.put(vec);
     phyPacketsRX <= phyPacketsRX + 1;
   endrule    

   rule transferTXVector;
     TXVector txvector <- mac.phy_txstart.get;
     $display("Transceiver: got a txStart packet");
     transceiver.transmitter.txStart(txvector);
     gct.txStart.put(txvector);
     dac.txStart.put(txvector);     
   endrule

   
 
   // CS decision
   //false positives may be an issue.
   // BUSY if we are transmitting or if AGC is doing things
   rule driveCS;
     let status <- gct.rxBusy.get;
     if(status) 
       begin
         csmaBusy <= csmaBusy + 1;
         mac.phy_cca_ind.put(BUSY);
       end
     else
       begin
         csmaIdle <= csmaIdle + 1;
         mac.phy_cca_ind.put(IDLE);
       end
   endrule


   // connect agc/rx ctrl
   rule packetFeedback;
     RXExternalFeedback feedback <- transceiver.receiver.packetFeedback.get;
     agc.packetFeedback.put(feedback); 
     gct.packetFeedback.put(feedback); 
 
     case(feedback)
       Abort: abort <= abort + 1;
     endcase 
   endrule

  //A second rule for handling the case that the MAC decides the packet is corrupt
  rule maccrcFeedback;
    RXExternalFeedback feedback <- mac.mac_abort.get;   
    macAbort <= macAbort + 1;
    $display("MAC abort: %d", macAbort+1);
  endrule

  // Setup the packet gen
  MACPacketGen packetGen <- mkMACPacketGen;
  MACPacketCheck packetCheck <- mkMACPacketCheck; 

  // hook packet gen/check to mac
  mkConnection(packetCheck.rxVector, mac.mac_sw_rxframe);    
  mkConnection(packetCheck.rxData, mac.mac_sw_rxdata);    
  mkConnection(mac.mac_sw_txframe,packetGen.txVector);   
  mkConnection(mac.mac_sw_txdata,packetGen.txData);   
  mkConnection(packetGen.txStatus,mac.mac_sw_txstatus);   

  // Setup the mac i/o
   
  mkCBusPut(valueof(MACAddrOffset), mac.mac_sa);
  mkCBusPut(valueof(MACAddrOffset), packetGen.localMACAddress);
  mkCBusPut(valueof(TargetMACAddrOffset), packetGen.targetMACAddress);

  // packet Gen externals
  mkCBusWideRegRW(valueof(AddrEnablePacketGen),packetGen.enablePacketGen);
  mkCBusWideRegR(valueof(AddrPacketsTX),packetGen.packetsTX);
  mkCBusWideRegR(valueof(AddrPacketsAcked),packetGen.packetsAcked);
  mkCBusWideRegRW(valueof(AddrMinPacketLength),packetGen.minPacketLength);
  mkCBusWideRegRW(valueof(AddrMaxPacketLength),packetGen.maxPacketLength);
  mkCBusWideRegRW(valueof(AddrPacketLengthMask),packetGen.packetLengthMask);
  mkCBusWideRegRW(valueof(AddrPacketDelay),packetGen.packetDelay);
  mkCBusWideRegRW(valueof(AddrRate),packetGen.rate);
  mkCBusWideRegR(valueof(AddrCycleCountTX),packetGen.cycleCount);

  // packet check externals
  mkCBusWideRegR(valueof(AddrPacketsRX),packetCheck.packetsRX);
  mkCBusWideRegR(valueof(AddrPacketsRXCorrect),packetCheck.packetsRXCorrect);
  mkCBusWideRegR(valueof(AddrGetBytesRX),packetCheck.bytesRX);
//   mkCBusWideRegR(valueof(AddrBER),packetCheck.ber);

  // GCT RF
  mkCBusPut(valueof(GCTOffset), gct.spiCommand);

  interface dacWires = dac.dacWires;
  interface adcWires = adc.adcWires;
  interface gctWires = gct.gctWires;
  interface spiWires = gct.spiWires;
  interface powerCtrlWires = powerCtrl;
  interface oobWires = oob.oobWires;

endmodule

/* This has become excessive.  we must REALLY refactor this crap. That this module is more than 500 lines is pretty ridiculous.  */
(* synthesize *)
module [Module]  mkTransceiverMACPacketGenFPGA#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;
   // do we want to line up the edges?
   // proabably need to set wait request during reset hold...
   Reset viterbiResetNew <- mkAsyncReset(2,rfReset,viterbiClock);
   Reset busResetNew <- mkAsyncReset(2,rfReset,busClock);
   Reset rfResetNew <- mkAsyncReset(2,rfReset,rfClock);
   Reset asicResetNew <- mkAsyncReset(2,rfReset,asicClock);

   let trans <- mkTransceiverMACPacketGenFPGAReset(viterbiClock, viterbiResetNew, busClock, busResetNew, rfClock, rfResetNew, clocked_by asicClock, reset_by asicResetNew);
   return trans;
endmodule

// We need a module to insert reset synchronizers
module [Module]  mkTransceiverMACPacketGenFPGAReset#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;

   AvalonSlave#(AvalonAddressWidth,AvalonDataWidth) busSlave <- mkAvalonSlave(asicClock,asicReset,clocked_by busClock, reset_by busReset);
   // Build up CReg interface   
   let ifc <- exposeCBusIFC(mkTransceiverMACPacketGenFPGAMonad(viterbiClock,viterbiReset,rfClock, rfReset));
  
   //Create a mapping...
   rule handleRequestRead(peekGet(busSlave.busClient.request).command ==  register_mapper::Read);
     let request <- busSlave.busClient.request.get;
     let readVal <- ifc.cbus_ifc.read(request.addr);
     $display("Transceiver Read Req addr: %x value: %x", request.addr, readVal);
     busSlave.busClient.response.put(readVal);
   endrule
 
   rule handleRequestWrite(peekGet(busSlave.busClient.request).command ==  register_mapper::Write);
     let request <- busSlave.busClient.request.get;
     $display("Transceiver Side Write Req addr: %x value: %x", request.addr, request.data);
     ifc.cbus_ifc.write(request.addr,request.data);
   endrule

  interface gctWires = ifc.device_ifc.gctWires;      
  interface adcWires = ifc.device_ifc.adcWires;
  interface dacWires = ifc.device_ifc.dacWires;
  interface spiWires = ifc.device_ifc.spiWires;
  interface powerCtrlWires = ifc.device_ifc.powerCtrlWires;
  interface avalonWires = busSlave.slaveWires;
  interface oobWires = ifc.device_ifc.oobWires;
endmodule
