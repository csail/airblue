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

`include "asim/provides/low_level_platform_interface.bsh"
`include "asim/provides/physical_platform.bsh"
`include "asim/provides/gordon_controller.bsh"
`include "asim/provides/gordon_common.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/plb_device_debug.bsh"
`include "asim/rrr/remote_server_stub_PLBDEBUGRRR.bsh"
`include "asim/rrr/remote_server_stub_GORDONWRAPPERSERVICERRR.bsh"



module [CONNECTED_MODULE] mkGordonWrapperService#(PHYSICAL_DRIVERS drivers) (); 

  plb_device_debug::ServerStub_PLBDEBUGRRR server_stubPLB <- plb_device_debug::mkServerStub_PLBDEBUGRRR();  
  ServerStub_GORDONWRAPPERSERVICERRR server_stub <- mkServerStub_GORDONWRAPPERSERVICERRR();   

  mkConnectPLBDebugger(server_stubPLB, 
                       drivers.gordonDriver.master, 
                       drivers.gordonDriver.slave); 

  // In theory we should do something with these

  rule handleDataCheck;
    let nullResp <- server_stubPLB.acceptRequest_getTestStatus();
    server_stubPLB.sendResponse_getTestStatus(0);
  endrule


  rule handleEndCheck;
    let nullResp <- server_stubPLB.acceptRequest_getTestReceived();
    server_stubPLB.sendResponse_getTestReceived(0);
  endrule

  // Handle controller debugs
    rule getExists;
      let nullReq <- server_stub.acceptRequest_readExistsBits();
      server_stub.sendResponse_readExistsBits(drivers.gordonDriver.busControllerDebug.existsBits[63:32],
                                              drivers.gordonDriver.busControllerDebug.existsBits[31:0]);

    endrule

    rule getReady;
      let nullReq <- server_stub.acceptRequest_readReadyBits();
      server_stub.sendResponse_readReadyBits(drivers.gordonDriver.busControllerDebug.readyBits[63:32],
                                             drivers.gordonDriver.busControllerDebug.readyBits[31:0]);

    endrule

    rule getLastLength;
      let nullReq <- server_stub.acceptRequest_readLastLength();
      server_stub.sendResponse_readLastLength(zeroExtend(drivers.gordonDriver.controllerDebug.lastLength));

    endrule

    rule getAccepted;
      let nullReq <- server_stub.acceptRequest_readAccepted();
      server_stub.sendResponse_readAccepted(zeroExtend(drivers.gordonDriver.controllerDebug.busDebugRegisters[0].acceptedRequestsCount),
                                            zeroExtend(drivers.gordonDriver.controllerDebug.busDebugRegisters[1].acceptedRequestsCount),
                                            zeroExtend(drivers.gordonDriver.controllerDebug.busDebugRegisters[2].acceptedRequestsCount),    
                                            zeroExtend(drivers.gordonDriver.controllerDebug.busDebugRegisters[3].acceptedRequestsCount));

    endrule

    rule getCommand;
      let nullReq <- server_stub.acceptRequest_readCommand();
      server_stub.sendResponse_readCommand(drivers.gordonDriver.busControllerDebug.command1[63:32],
                                               drivers.gordonDriver.busControllerDebug.command1[31:0],
                                               drivers.gordonDriver.busControllerDebug.command2[63:32],
                                               drivers.gordonDriver.busControllerDebug.command2[31:0]);

    endrule



endmodule
