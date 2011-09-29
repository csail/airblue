//
// Copyright (C) 2008 Intel Corporation
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

import FIFOF::*;
import GetPut::*;
import Connectable::*;
import CBus::*;
import Clocks::*;
import FIFO::*;
import FixedPoint::*;
import Complex::*;

`include "asim/provides/low_level_platform_interface.bsh"
`include "asim/provides/physical_platform.bsh"
`include "asim/provides/sata_device.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/soft_clocks.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/rrr/remote_server_stub_SATARRR.bsh"


typedef union tagged {
  void EndOfPacket;
  SynchronizerMesg#(RXFPIPrec,RXFPFPrec) Sample;  
} USRPPacket deriving (Bits, Eq);

typedef enum {
  Idle,
  Command, 
  Body
} PacketState deriving (Bits, Eq);

XUPV5_SERDES_WORD sampleSyncWord = serdesWord(serdesControl(156),serdesControl(156));

module [CONNECTED_MODULE] mkAirblueService#(PHYSICAL_DRIVERS drivers) (); 

   XUPV5_SERDES_DRIVER       sataDriver = drivers.sataDriver;
   Clock rxClk = sataDriver.rxusrclk0;
   Clock txClk = sataDriver.txusrclk;
   Reset rxRst = sataDriver.rxusrrst0; 
   Reset txRst = sataDriver.txusrrst;


   ServerStub_SATARRR serverStub <- mkServerStub_SATARRR();

   Integer fifo_sz = 16383;
   FIFOF#(Bit#(32)) sampleStream <- mkStreamCaptureFIFOF(fifo_sz);


   FIFOF#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) serdes_word_fifo <- mkSizedBRAMFIFOF(fifo_sz, clocked_by rxClk, reset_by rxRst);
   SyncFIFOIfc#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) serdes_word_sync_fifo <- mkSyncFIFOToCC(16,rxClk, rxRst);


   Reg#(Bool) processI <- mkReg(True, clocked_by(rxClk), reset_by(rxRst)); // Expect to start in the processing I state
   Reg#(FixedPoint#(RXFPIPrec,RXFPFPrec)) iPart <- mkReg(0, clocked_by(rxClk), reset_by(rxRst));
   // make soft connections to PHY
   Connection_Send#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Send("AnalogReceive");
   Reg#(Bit#(40)) rxCount <- mkReg(0, clocked_by(rxClk), reset_by(rxRst));
   Reg#(Bit#(40)) rxCountCC <- mkSyncRegToCC(0,rxClk,rxRst);    
   Reg#(Bit#(40)) sampleDropped <- mkReg(0, clocked_by(rxClk), reset_by(rxRst));
   Reg#(Bit#(40)) sampleDroppedCC <- mkSyncRegToCC(0,rxClk,rxRst);    
   Reg#(Bit#(32)) realign <- mkReg(0, clocked_by(rxClk), reset_by(rxRst));
   Reg#(Bit#(64)) realignCC <- mkSyncRegToCC(0,rxClk,rxRst);    
   Reg#(Bit#(32)) rxErrorsCC <- mkSyncRegToCC(0,rxClk,rxRst);    
   Reg#(Bit#(40)) sampleSent <- mkReg(0, clocked_by(rxClk), reset_by(rxRst));
   Reg#(Bit#(40)) sampleSentCC <- mkSyncRegToCC(0,rxClk,rxRst);    
   ReadOnly#(Bool) txRstVal <- isResetAsserted(clocked_by(txClk), reset_by(txRst));
   Reg#(Bool)      txRstValCC <- mkSyncRegToCC(False,txClk,txRst); 
   
   rule rxCountTransfer;
     rxCountCC <= rxCount;
   endrule

   rule sampleDroppedTransfer;
     sampleDroppedCC <= sampleDropped;
   endrule

   rule sampleSentTransfer;
     sampleSentCC <= sampleSent;
   endrule

   rule realignTransfer;
     realignCC <= {sataDriver.realignment0,realign};
   endrule

   rule errorTransfer;
     rxErrorsCC <= sataDriver.errors0;
   endrule

   rule getSampleRX;
     let dummy <- serverStub.acceptRequest_GetRXCount();
     serverStub.sendResponse_GetRXCount(zeroExtend(rxCountCC));
   endrule

   rule getSampleDropped;
     let dummy <- serverStub.acceptRequest_GetSampleDropped();
     serverStub.sendResponse_GetSampleDropped(zeroExtend(sampleDroppedCC));
   endrule

   rule getSampleSent;
     let dummy <- serverStub.acceptRequest_GetSampleSent();
     serverStub.sendResponse_GetSampleSent(zeroExtend(sampleSentCC));
   endrule

   rule getRXError;
     let dummy <- serverStub.acceptRequest_GetRXErrors();
     serverStub.sendResponse_GetRXErrors(zeroExtend(pack(rxErrorsCC)));
   endrule

   rule getRealign;
     let dummy <- serverStub.acceptRequest_GetRealign();
     serverStub.sendResponse_GetRealign(pack(realignCC));
   endrule

   rule getSample;
     let dummy <- serverStub.acceptRequest_GetSample();
     sampleStream.deq();
     serverStub.sendResponse_GetSample(sampleStream.first);
   endrule

   rule processIPart (processI);
       XUPV5_SERDES_WORD dataIn <- sataDriver.receive0();
       rxCount <= rxCount + 1;
       // We should only use this if it is not control 
       // although we may see a sync control word here, we 
       if(extractData(dataIn) matches tagged Valid .data) 
         begin
           processI <= False; 
           iPart <= data;
         end
    endrule

    rule sendToSW (!processI && serdes_word_fifo.notFull);
      XUPV5_SERDES_WORD dataIn <- sataDriver.receive0();
      rxCount <= rxCount + 1;
       // This may be a bug Alfred will know what to do. XXX
       if(extractData(dataIn) matches tagged Valid .data)
         begin
           sampleSent <= sampleSent + 1;
           serdes_word_fifo.enq(cmplx(iPart,data));
           processI <= True;
         end 
       else if(dataIn == sampleSyncWord) // In this case we should be receiving a real next
         begin
           processI <= True;
           realign <= realign + 1;
         end
    endrule

    rule dropdata (!processI && !serdes_word_fifo.notFull);
       XUPV5_SERDES_WORD dataIn <- sataDriver.receive0();
       rxCount <= rxCount + 1;
       // This may be a bug Alfred will know what to do. XXX
       if(extractData(dataIn) matches tagged Valid .data)
         begin
           // Here we must drop the data
           sampleDropped <= sampleDropped + 1;
           processI <= True;
           iPart <= data;
         end
    endrule

    // send to sync fifo
    rule toSync;
       serdes_word_fifo.deq;
       serdes_word_sync_fifo.enq(serdes_word_fifo.first());       
    endrule

    rule toAnalog;
       serdes_word_sync_fifo.deq;
       analogRX.send(serdes_word_sync_fifo.first());       
    endrule

    rule toStreamCapture;
       sampleStream.enq(pack(serdes_word_sync_fifo.first()));
    endrule

    // Handle the TX side.  The general strategy is to create a XMHz channel and apply Little's law -
    // If the ingress into the channel is not XMhz, then the egress is not 20Mhz.  If we assume we have a 
    // correct baseband then this can be used to detect packet boundaries. 
    

    Connection_Receive#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Receive("AnalogTransmit");

    Reg#(Bit#(TAdd#(1,TLog#(`MODEL_CLOCK_FREQ)))) counter <- mkReg(0); 

    FIFOF#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) intxfifo <- mkSizedFIFOF(32);  
    FIFO#(Bit#(1)) creditfifo <- mkSizedFIFO(`SAMPLE_RATE);  // A basic credit scheme to avoid the need for complex flow control
    SyncFIFOIfc#(USRPPacket) outtxfifo <- mkSyncFIFOFromCC(32, txClk);  // this one goes to serdes
     // USRP expects a packetized data stream with a two word heade
     // and tied off by an end of buffer tag.
     // We will send the end of buffer as a control value, but the header
     // are normal samples.

     // Fix endianess for i/q
     Reg#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) usrpMagic0 <- mkReg(unpack('hdead0007));
     Reg#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) usrpMagic1 <- mkReg(unpack('hcafecafe));


    Reg#(PacketState) state <- mkReg(Idle);
    Reg#(Bit#(40)) txCountIn <- mkReg(0);  
    Reg#(Bit#(40)) txCount <- mkReg(0, clocked_by(txClk), reset_by(txRst));  
    Reg#(Bit#(40)) txCountCC <- mkSyncRegToCC(0,txClk,txRst); 


   rule txCountTransfer;
     txCountCC <= txCount;
   endrule

   rule txRstTransfer;
     txRstValCC <= txRstVal;
   endrule


   rule tickCredit;
     if(counter + 1 == `MODEL_CLOCK_FREQ)
       begin
         counter <= 0;
       end     
     else 
       begin
       	 counter <= counter + 1;
       end
     if(counter < `SAMPLE_RATE)
       begin
         creditfifo.enq(0);
       end
   endrule

   rule setUSRPHeader;
     let dummy <- serverStub.acceptRequest_SetUSRPHeader();
     usrpMagic0 <= unpack(pack(dummy.magic0));
     usrpMagic1 <= unpack(pack(dummy.magic1));
   endrule

   rule getSampleTX;
     let dummy <- serverStub.acceptRequest_GetTXCount();
     serverStub.sendResponse_GetTXCount(zeroExtend(txCountCC));
   endrule

   rule getSampleTXIn;
     let dummy <- serverStub.acceptRequest_GetTXCountIn();
     serverStub.sendResponse_GetTXCountIn(zeroExtend(txCountIn));
   endrule

    rule forwardToLL; 
      analogTX.deq();
      txCountIn <= txCountIn + 1;
      intxfifo.enq(analogTX.receive());
    endrule


    rule handleIdleState(state == Idle && intxfifo.notEmpty);
      outtxfifo.enq(tagged Sample usrpMagic0);
      state <= Command;    
      creditfifo.deq;
    endrule

    rule handleCommandState(state == Command);
      outtxfifo.enq(tagged Sample usrpMagic1);
      state <= Body;
      creditfifo.deq;
    endrule

    rule handleBodyState(state == Body && intxfifo.notEmpty);
      outtxfifo.enq(tagged Sample intxfifo.first);
      intxfifo.deq;
      creditfifo.deq;
    endrule

    // We're done
    rule handleCompletion(state == Body && !intxfifo.notEmpty);
      outtxfifo.enq(tagged EndOfPacket);
      state <= Idle;
      creditfifo.deq;
    endrule
  
    // Finally we should demarshall the data for transmission 
    Reg#(Bit#(16)) sendSync <- mkReg(maxBound, clocked_by(txClk), reset_by(txRst));
    Reg#(Bool) deqNeeded <- mkReg(False, clocked_by(txClk), reset_by(txRst));
  
    rule tickDown(sendSync > 0);
      sendSync <= sendSync - 1 ;
    endrule

    function Action handleDeq();
      action
        if(deqNeeded)
          begin
	    outtxfifo.deq();
          end
        deqNeeded <= !deqNeeded;
      endaction
    endfunction

    rule sendToSERDESData(outtxfifo.first matches tagged Sample .data);
      Bit#(16) chunk = deqNeeded?pack(data.img):pack(data.rel); // send MSB/rel first
      sataDriver.send0(serdesWord(serdesData(chunk[15:8]),serdesData(chunk[7:0])));  // Byte endian issue?
      txCount <= txCount + 1;
      handleDeq();
    endrule

    rule sendToSERDESCtrl(outtxfifo.first matches tagged EndOfPacket);
      // This ~0 signifies control
      sataDriver.send0(serdesWord(serdesControl(124),serdesControl(124)));
      handleDeq();
    endrule
 

    // We use this control word to indicate even parity
    rule sendToSERDESSync(!outtxfifo.notEmpty && sendSync == 0);
      // This 156 signifies a synchronization event
      sataDriver.send0(sampleSyncWord);
      sendSync <= maxBound;
    endrule


endmodule
