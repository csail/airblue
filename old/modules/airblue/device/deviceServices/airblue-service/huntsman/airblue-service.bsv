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

`include "asim/provides/low_level_platform_interface.bsh"
`include "asim/provides/physical_platform.bsh"
`include "asim/provides/airblue_rf_device.bsh"
import AirblueCommon::*;
import AirblueTypes::*;
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/rf_driver.bsh"
`include "asim/provides/spi.bsh"
`include "asim/rrr/remote_server_stub_SPIMASTERRRR.bsh"
`include "asim/rrr/remote_server_stub_CBUSRFRRR.bsh"


module [CONNECTED_MODULE] mkAirblueService#(PHYSICAL_DRIVERS drivers) (); 

  // Instantiate debugger RRR...
  ServerStub_SPIMASTERRRR spi_server_stub <- mkServerStub_SPIMASTERRRR();   
  ServerStub_CBUSRFRRR rf_cbus_server_stub <- mkServerStub_CBUSRFRRR();   

  // Handle RRR CBUS

  rule handleRequestRead;
    let request <- rf_cbus_server_stub.acceptRequest_RFRead();
     
    // Choose among sender and receiver
    let readVal <- drivers.rfDriver.busWires.read(truncate(pack(request)));
    if(`DEBUG_RF_DEVICE == 1)
      begin
        $display("Transceiver Read Req addr: %x value: %x", request, readVal);
      end
    rf_cbus_server_stub.sendResponse_RFRead(unpack(readVal));
  endrule
 
  rule handleRequestWrite;
    let request <- rf_cbus_server_stub.acceptRequest_RFWrite();
    if(`DEBUG_RF_DEVICE == 1)
      begin
        $display("Transceiver Side Write Req addr: %x value: %x", request.addr, request.data);
      end

    drivers.rfDriver.busWires.write(truncate(pack(request.addr)),pack(request.data));
  endrule

   // Handle RRR SPI

  rule handleRequestReadReqSPI;
    let request <- spi_server_stub.acceptRequest_SPIRead();
    //SPI does not support read, at present.  
  endrule
 
  rule handleRequestWriteSPI;
    let request <- spi_server_stub.acceptRequest_SPIWrite();
    drivers.rfDriver.spiCommand.put(SPIMasterRequest{slave:truncate(request.addr),
                                                     data:truncate(request.data)});
   endrule

   // make soft connections to PHY
   Connection_Receive#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Receive("AnalogTransmit");

   mkConnection(analogTX, drivers.rfDriver.rfIn);

   Connection_Send#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Send("AnalogReceive");
   
   mkConnection(drivers.rfDriver.rfOut,analogRX);  
   


endmodule
