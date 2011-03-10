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

// USRP expects a packetized data stream with a two word heade
// and tied off by an end of buffer tag.
// We will send the end of buffer as a control value, but the header
// are normal samples.

SynchronizerMesg#(RXFPIPrec,RXFPFPrec) usrpMagic0 = unpack('h6);
SynchronizerMesg#(RXFPIPrec,RXFPFPrec) usrpMagic1 = unpack(0);


module [CONNECTED_MODULE] mkAirblueService#(PHYSICAL_DRIVERS drivers) (); 

   XUPV5_SERDES_DRIVER       sataDriver = drivers.sataDriver;
   Clock rxClk = sataDriver.rxusrclk0;
   Clock txClk = sataDriver.txusrclk;
   Reset rxRst = sataDriver.rxusrrst0; 
   Reset txRst = sataDriver.txusrrst;


   ServerStub_SATARRR serverStub <- mkServerStub_SATARRR();

   NumTypeParam#(16383) fifo_sz = 0;
   FIFO#(XUPV5_SERDES_WORD) serdes_word_fifo <- mkSizedBRAMFIFO(fifo_sz, clocked_by rxClk, reset_by rxRst);
   SyncFIFOIfc#(XUPV5_SERDES_WORD) serdes_word_sync_fifo <- mkSyncFIFOToCC(16,rxClk, rxRst);


   Reg#(Bool) processI <- mkReg(True); // Expect to start in the processing I state
   Reg#(FixedPoint#(RXFPIPrec,RXFPFPrec)) iPart <- mkReg(0);
   // make soft connections to PHY
   Connection_Send#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Send("AnalogReceive");
   Reg#(Bit#(40)) rxCount <- mkReg(0, clocked_by(rxClk), reset_by(rxRst));
   Reg#(Bit#(40)) rxCountCC <- mkSyncRegToCC(0,rxClk,rxRst);    
   
   rule rxCountTransfer;
     rxCountCC <= rxCount;
   endrule

   rule getSampleRX;
     let dummy <- serverStub.acceptRequest_GetRXCount();
     serverStub.sendResponse_GetRXCount(zeroExtend(rxCountCC));
   endrule

   rule getSATAData(True);
      let data <- sataDriver.receive0();
      serdes_word_fifo.enq(data);
      rxCount <= rxCount + 1;
   endrule

    rule crossClockSATAData(True);
      serdes_word_fifo.deq();
      serdes_word_sync_fifo.enq(serdes_word_fifo.first());
    endrule


    rule processIPart (processI);
       serdes_word_sync_fifo.deq();
       // We should only use this if it is not control 
       if(extractData(serdes_word_sync_fifo.first()) matches tagged Valid .data) 
         begin
           processI <= False; 
           iPart <= data;
         end
    endrule

    rule sendToSW (!processI);
       serdes_word_sync_fifo.deq();
       // This may be a bug Alfred will know what to do. XXX
       if(extractData(serdes_word_sync_fifo.first()) matches tagged Valid .data)
         begin
           analogRX.send(cmplx(iPart,data));
           processI <= True;
         end 
    endrule


    // Handle the TX side.  The general strategy is to create a XMHz channel and apply Little's law -
    // If the ingress into the channel is not XMhz, then the egress is not 20Mhz.  If we assume we have a 
    // correct baseband then this can be used to detect packet boundaries. 
    

    UserClock clkSample <- mkSoftClock(`SAMPLE_RATE); // use this to assemble the packets according to the expected sampling rate

    Connection_Receive#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Receive("AnalogTransmit");

    SyncFIFOIfc#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) intxfifo <- mkSyncFIFOFromCC(32, clkSample.clk);  
    SyncFIFOIfc#(USRPPacket) outtxfifo <- mkSyncFIFO(32, clkSample.clk, clkSample.rst, txClk);  // this one goes to serdes
    Reg#(PacketState) state <- mkReg(Idle, clocked_by(clkSample.clk), reset_by(clkSample.rst));
    Reg#(Bit#(40)) txCount <- mkReg(0, clocked_by(txClk), reset_by(txRst));  
    Reg#(Bit#(40)) txCountCC <- mkSyncRegToCC(0,txClk,txRst); 

   rule txCountTransfer;
     txCountCC <= txCount;
   endrule

   rule getSampleTX;
     let dummy <- serverStub.acceptRequest_GetTXCount();
     serverStub.sendResponse_GetTXCount(zeroExtend(txCountCC));
   endrule

    rule forwardToLL; 
      analogTX.deq();
      intxfifo.enq(analogTX.receive());
    endrule


    rule handleIdleState(state == Idle && intxfifo.notEmpty);
      outtxfifo.enq(tagged Sample usrpMagic0);
      state <= Command;    
    endrule

    rule handleCommandState(state == Idle);
      outtxfifo.enq(tagged Sample usrpMagic1);
      state <= Body;
    endrule

    rule handleBodyState(state == Body && intxfifo.notEmpty);
      outtxfifo.enq(tagged Sample intxfifo.first);
      intxfifo.deq;
    endrule

    // We're done
    rule handleCompletion(state == Body && !intxfifo.notEmpty);
      outtxfifo.enq(tagged EndOfPacket);
      state <= Idle;
    endrule
  
    // Finally we should demarshall the data for transmission 
    Reg#(Bool) deqNeeded <- mkReg(False, clocked_by(txClk), reset_by(txRst));
  
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
      Bit#(16) chunk = deqNeeded?pack(data)[15:0]:pack(data)[31:16]; // send MSB first
      sataDriver.send0(unpackRxWord(0,0,pack(chunk),?));
      handleDeq();
    endrule

    rule sendToSERDESCtrl(outtxfifo.first matches tagged EndOfPacket);
      // This ~0 signifies control
      sataDriver.send0(unpackRxWord(0,~0,0,?));
      handleDeq();
    endrule
 
endmodule
