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
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/librl_bsv_base.bsh"

module [CONNECTED_MODULE] mkAirblueService#(PHYSICAL_DRIVERS drivers) (); 

   XUPV5_SERDES_DRIVER       sataDriver = drivers.sataDriver;
   Clock rxClk = sataDriver.rxusrclk0;
   Reset rxRst = sataDriver.rxusrrst0;

   NumTypeParam#(16383) fifo_sz = 0;
   FIFO#(XUPV5_SERDES_WORD) serdes_word_fifo <- mkSizedBRAMFIFO(fifo_sz, clocked_by rxClk, reset_by rxRst);
   SyncFIFOIfc#(XUPV5_SERDES_WORD) serdes_word_sync_fifo <- mkSyncFIFOToCC(16,rxClk, rxRst);

   Reg#(Bool) processI <- mkReg(True); // Expect to start in the processing I state
   Reg#(FixedPoint#(RXFPIPrec,RXFPFPrec)) iPart <- mkReg(0);
   // make soft connections to PHY
   Connection_Receive#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Receive("AnalogTransmit");
   Connection_Send#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Send("AnalogReceive");

    rule getSATAData(True);
       let data <- sataDriver.receive0();
       serdes_word_fifo.enq(data);
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

    rule tieOff; // Should be removed at some point
      analogTX.deq();
    endrule
   
endmodule
