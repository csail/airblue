import GetPut::*;
import FIFO::*;
import FIFOLevel::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/rrr/remote_server_stub_PACKETGENRRR.bsh"

// maybe parameterize by generation algorithm at some point
module [CONNECTED_MODULE] mkPacketGen (Empty);

  ServerStub_PACKETGENRRR serverStub <- mkServerStub_PACKETGENRRR();

  Connection_Send#(TXVector) txVectorFIFO <- mkConnection_Send("TXVector");
  Connection_Send#(Bit#(8))  txDataFIFO <-   mkConnection_Send("TXData");
  Connection_Send#(Bit#(1))  txEnd    <- mkConnection_Send("TXEnd");

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

endmodule