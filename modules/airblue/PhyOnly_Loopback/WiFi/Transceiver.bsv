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
import ClientServer::*;
import Clocks::*;

// import AvalonSlave::*;
// import AvalonCommon::*;
// import CBusUtils::*;
// import SPIMaster::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import ProtocolParameters::*;
// import FPGAParameters::*;
// import LibraryFunctions::*;
// import FPComplex::*;
// import Synchronizer::*;
// import FPComplex::*;
// import PacketGen::*;
// import WiFiReceiver::*;
// import WiFiTransmitter::*;
// import MACPhyParameters::*;

// import GCT::*;
// import AD::*;
// import Power::*;
// import AGC::*;
// import OutOfBand::*;

// Local includes
`include "asim/provides/airblue_device.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/spi.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_phy_packet_gen.bsh"
`include "asim/provides/airblue_phy.bsh"

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

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkTransceiverPacketGenFPGAMonad#(Clock viterbiClock, Reset viterbiReset, Clock rfClock, Reset rfReset) (TransceiverASICWires);
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;

   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerTimeOut = CRAddr{a: fromInteger(valueof(AddrSynchronizerTimeOut)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainHoldStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainHoldStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerGainStart = CRAddr{a: fromInteger(valueof(AddrSynchronizerGainStart)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrSynchronizerLongSync = CRAddr{a: fromInteger(valueof(AddrSynchronizerLongSync)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXControlAbort = CRAddr{a: fromInteger(valueof(AddrRXControlAbort)) , o: 0};   

   // Fix me at some point
   Reg#(Bit#(32)) gainStart <- mkCBRegR(addrSynchronizerGainStart,0);
   Reg#(Bit#(32)) gholdStart<- mkCBRegR(addrSynchronizerGainHoldStart,0);
   Reg#(Bit#(32)) timeOut   <- mkCBRegR(addrSynchronizerTimeOut,0);
   Reg#(Bit#(32)) longSync <- mkCBRegR(addrSynchronizerLongSync,0);

   Reg#(Bit#(32)) abort <- mkCBRegR(addrRXControlAbort,0);

   WiFiTransceiver transceiver <- mkTransceiver(viterbiClock,viterbiReset);
   GCT  gct <- mkGCT;
   DAC  dac <- mkDAC(clock, reset, clocked_by rfClock, reset_by rfReset);
   ADC  adc <- mkADC(clock, reset, clocked_by rfClock, reset_by rfReset);
   AGC  agc <- mkAGC;
   PowerCtrlWires powerCtrl <- mkPowerCtrl; 
   OutOfBand oob <- mkOutOfBand();

   // packet gen crap
   PacketGen packetGen <- mkPacketGen;
   PacketCheck packetCheck <- mkPacketCheck;


   // packet Gen externals
   mkCBusWideRegRW(valueof(AddrEnablePacketGen),packetGen.enablePacketGen);
   mkCBusWideRegR(valueof(AddrPacketsTX),packetGen.packetsTX);
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
   mkCBusWideRegR(valueof(AddrGetBytesRXCorrect),packetCheck.bytesRXCorrect);
   mkCBusWideRegR(valueof(AddrBER),packetCheck.ber);


   // hook up TX controlflow
   rule txCompleteNotify;
     let in <- dac.txComplete;
     gct.txComplete.put(in);
     // Drive external completion signal
     // Drive it for a little bit longer than we expect to receive, just to ensure
     // that we latch the signal
     oob.driveExternalTriggerOutput(100);
   endrule


   // hook the Synchronizer to feedback points  
   rule synchronizerFeedback;
     ControlType ctrl <- transceiver.receiver.synchronizerStateUpdate.get;
     gct.synchronizerStateUpdate.put(ctrl);
     agc.synchronizerStateUpdate.put(ctrl);
     // update ctrl counts
     case (ctrl) 
      GainStart:  gainStart <= gainStart + 1;
      GHoldStart: gholdStart <= gholdStart + 1;
      TimeOut:    timeOut <= timeOut + 1;
      LongSync:   longSync <= longSync + 1;
     endcase

   endrule
   
   // connect agc/rx ctrl
   rule packetFeedback;
     RXExternalFeedback feedback <- transceiver.receiver.packetFeedback.get;
     agc.packetFeedback.put(feedback); 
     gct.packetFeedback.put(feedback);

     case(feedback)
       Abort: begin 
                abort <= abort + 1;
                
              end
     endcase
   endrule

   // Drive adc trigger off of the external signal
   rule driveADCTrigger;
     if(oob.sampleExternalTriggerInput(50))
       begin
         adc.triggerCapture();
       end
   endrule

   // hook up the DAC/ADC
   mkConnection(transceiver.receiver.in,adc.dataIn);
   if(`DEBUG_TRANSCEIVER == 1)
      begin
         mkConnectionThroughput("CP->DAC",transceiver.transmitter.out,dac.dataOut);
      end
   else
      begin
         mkConnection(transceiver.transmitter.out,dac.dataOut);
      end
   
   rule sendGainToADC;
     dac.agcGainSet(agc.outputGain);
   endrule

   rule sendPowToAGC;
     agc.inputPower(transceiver.receiver.synchronizerCoarPower);
   endrule
   

   // Build up CReg interface   
   // Receiver Side   
   mkConnection(packetCheck.rxVector,transceiver.receiver.outRXVector);
   mkConnection(packetCheck.rxData,transceiver.receiver.outData);
   mkConnection(packetCheck.abortAck,transceiver.receiver.abortAck);
   
   rule connectAbortReq (True);
      let dont_care <- packetCheck.abortReq.get;
      transceiver.receiver.abortReq;
   endrule

   // Transmitter Side
      

   rule txVecSend;
     // spread the tx vec love
      TXVector txVec <- packetGen.txVector.get;
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver: TX start");
         end
      transceiver.transmitter.txStart(txVec);
      gct.txStart.put(txVec);
      dac.txStart.put(txVec); 
   endrule
   
   mkConnection(transceiver.transmitter.txData,packetGen.txData.get);   

  // GCT RF
  mkCBusPut(valueof(GCTOffset), gct.spiCommand);

 
  interface dacWires = dac.dacWires;
  interface adcWires = adc.adcWires;
  interface gctWires = gct.gctWires;
  interface spiWires = gct.spiWires;
  interface powerCtrlWires = powerCtrl;
  interface oobWires = oob.oobWires;

endmodule

(* synthesize *)
module [Module]  mkTransceiverPacketGenFPGA#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;
   // do we want to line up the edges?
   // proabably need to set wait request during reset hold...
   Reset viterbiResetNew <- mkAsyncReset(2,rfReset,viterbiClock);
   Reset busResetNew <- mkAsyncReset(2,rfReset,busClock);
   Reset rfResetNew <- mkAsyncReset(2,rfReset,rfClock);
   Reset asicResetNew <- mkAsyncReset(2,rfReset,asicClock);

   let trans <- mkTransceiverPacketGenFPGAReset(viterbiClock, viterbiResetNew, busClock, busResetNew, rfClock, rfResetNew, clocked_by asicClock, reset_by asicResetNew);
   return trans;
endmodule

// We need a module to insert reset synchronizers
module [Module]  mkTransceiverPacketGenFPGAReset#(Clock viterbiClock, Reset viterbiReset, Clock busClock, Reset busReset, Clock rfClock, Reset rfReset) (TransceiverFPGA);
   Clock asicClock <- exposeCurrentClock;
   Reset asicReset <- exposeCurrentReset;


   AvalonSlave#(AvalonAddressWidth,AvalonDataWidth) busSlave <- mkAvalonSlave(asicClock,asicReset,clocked_by busClock, reset_by busReset);
   // Build up CReg interface   
   let ifc <- exposeCBusIFC(mkTransceiverPacketGenFPGAMonad(viterbiClock,viterbiReset,rfClock, rfReset));
  
   //Create a mapping...
   rule handleRequestRead(peekGet(busSlave.busClient.request).command ==  register_mapper::Read);
      let request <- busSlave.busClient.request.get;
      let readVal <- ifc.cbus_ifc.read(request.addr);
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver Read Req addr: %x value: %x", request.addr, readVal);
         end
      busSlave.busClient.response.put(readVal);
   endrule
 
   rule handleRequestWrite(peekGet(busSlave.busClient.request).command ==  register_mapper::Write);
      let request <- busSlave.busClient.request.get;
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver Side Write Req addr: %x value: %x", request.addr, request.data);
         end
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

