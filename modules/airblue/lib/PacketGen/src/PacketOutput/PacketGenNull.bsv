import GetPut::*;
import FIFO::*;
import FIFOLevel::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/rrr/remote_server_stub_PACKETGENRRR.bsh"

interface PacketGen;
  // for hooking up to the baseband
  interface Get#(TXVector) txVector;
  interface Get#(Bit#(8)) txData;
endinterface

// maybe parameterize by generation algorithm at some point
module [CONNECTED_MODULE] mkPacketGen (PacketGen);

  ServerStub_PACKETGENRRR serverStub <- mkServerStub_PACKETGENRRR();

  rule setRate;
    let rate <- serverStub.acceptRequest_SetRate();
  endrule

  rule setMax;
    let maxNew <- serverStub.acceptRequest_SetMaxLength();
  endrule

  rule setMin;
    let minNew <- serverStub.acceptRequest_SetMinLength();
  endrule

  rule setEnable;
    let enableNew <- serverStub.acceptRequest_SetEnable();
  endrule


  interface txVector = ?; 
  interface txData = ?; 

endmodule