//
// Copyright (C) 2008 Massachusetts Institute of Technology
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

import Vector::*;

`include "asim/provides/virtual_platform.bsh"
`include "asim/provides/virtual_devices.bsh"
`include "asim/provides/low_level_platform_interface.bsh"
`include "asim/provides/rrr.bsh"

`include "asim/provides/soft_connections.bsh"

`include "asim/provides/common_services.bsh"
`include "asim/provides/airblue_service.bsh"
`include "asim/rrr/server_connections.bsh"
`include "asim/rrr/client_connections.bsh"


//
// mkPlatformInterface: Wrap the LLPI and virtual devices in soft connections.
//

module [CONNECTED_MODULE] mkPlatformServices#(VIRTUAL_PLATFORM virtualPlatform)
    // interface
        ();

    // Get a link to the LLPI.
    VIRTUAL_DEVICES vdevs = virtualPlatform.virtualDevices;

    // Instantiate soft interfaces to the virtual devices
    let commonServices  <- mkCommonServices(vdevs);
    let airblueService <- mkAirblueService(virtualPlatform.llpint.physicalDrivers);

    // auto-generated submodules for RRR connections
    let rrrServerLinks <- mkServerConnections(virtualPlatform.llpint.rrrServer);
    let rrrClientLinks <- mkClientConnections(virtualPlatform.llpint.rrrClient);
    

endmodule
