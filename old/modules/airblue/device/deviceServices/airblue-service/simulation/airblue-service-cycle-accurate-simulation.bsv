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
import Complex::*;
import Vector::*;


`include "asim/provides/low_level_platform_interface.bsh"
`include "asim/provides/physical_platform.bsh"
import AirblueCommon::*;
import AirblueTypes::*;
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_connections.bsh"


import "BDPI" function ActionValue#(Bit#(32))  input_sample();

module [CONNECTED_MODULE] mkAirblueService#(PHYSICAL_DRIVERS drivers) (); 

   // make soft connections to PHY
   Connection_Receive#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Receive("AnalogTransmit");

   Connection_Send#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Send("AnalogReceive");

  // XXX For now we don't care about TX, but we might at some point. 
 
  Reg#(Bit#(32)) cycle <- mkReg(0);
   
  rule cycleUp;
    cycle <= cycle + 1; 
  endrule 

  rule handleRX; 
    let data <- input_sample();
    $display("Cycle:%d Sending sample: %h", cycle,data);
    analogRX.send(unpack(data));
  endrule


endmodule
