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
import Complex::*;

`include "asim/provides/low_level_platform_interface.bsh"
`include "asim/provides/physical_platform.bsh"
`include "asim/provides/airblue_rf_device.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/rrr/remote_server_stub_AIRBLUERFSIM.bsh"


module [CONNECTED_MODULE] mkAirblueService#(PHYSICAL_DRIVERS drivers) (); 

   ClientStub_AIRBLUERFSIM rx_client_stub <- mkServerStub_AIRBLUERFSIM();

   // make soft connections to PHY
   Connection_Receive#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Receive("AnalogTransmit");

   Connection_Send#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Send("AnalogReceive");

  // XXX For now we don't care about TX, but we might at some point. 
 
  rule handleRX;
    let data <-  server_stub.acceptRequest_IQStream();
    // we might need some AGC here at some point
    SynchronizerMesg#(RXFPIPrec,RXFPFPrec) sample = 
      Complex{img: unpack(truncateLSB(data[31:16])),
              rel: unpack(truncateLSB(data[15:0]))};

    analogRX.send(sample);

  endrule



endmodule
