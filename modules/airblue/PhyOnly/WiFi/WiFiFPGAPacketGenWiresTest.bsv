//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

import ClientServer::*;
import Vector::*;
import Clocks::*;
import Complex::*;
import FixedPoint::*;
import GetPut::*;
import StmtFSM::*;
import CBus::*;


// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/client_server_utils.bsh"
`include "asim/provides/register_mapper.bsh"
`include "asim/provides/register_library.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_clocks.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_CBUSVECTORCONTROLRRR.bsh"

//For the wires test we swap for two transceivers here.
module [CONNECTED_MODULE] mkBusTransceiver#(Clock viterbiClock, Reset viterbiReset) ();
 
  let transceiverFPGA <-  mkTransceiverPacketGenFPGA(viterbiClock, viterbiReset);


  // Instantiate host communications
 
  ServerStub_CBUSVECTORCONTROLRRR server_stub <- mkServerStub_CBUSVECTORCONTROLRRR();


  rule handleRequestRead;
      let request <- server_stub.acceptRequest_Read();
     
      // Choose among sender and receiver
      let readVal <- transceiverFPGA.cbus_ifc.read(truncate(pack(request)));
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver Read Req addr: %x value: %x", request, readVal);
         end
      server_stub.sendResponse_Read(unpack(readVal));
   endrule
 
   rule handleRequestWrite;
      let request <- server_stub.acceptRequest_Write();

      if(`DEBUG_TRANSCEIVER == 1)
        begin
          $display("Transceiver Side Write Req addr: %x value: %x", request.addr, request.data);
        end

      transceiverFPGA.cbus_ifc.write(truncate(pack(request.addr)),pack(request.data));
   endrule

   // Hookup RF frontend communications

   Connection_Send#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Send("AnalogTransmit");

   mkConnection(transceiverFPGA.basebandOut,analogTX);

   Connection_Receive#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Receive("AnalogReceive");
   
   mkConnection(analogRX,transceiverFPGA.basebandIn); 
   

endmodule

module [CONNECTED_MODULE] mkWiFiFPGAPacketGenWiresTest ();
  UserClock viterbi <- mkSoftClock(60);//mkUserClock_PLL(`CRYSTAL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,60);
  
  let m <- mkBusTransceiver(viterbi.clk, viterbi.rst);
endmodule
                               
module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
   let test <- mkWiFiFPGAPacketGenWiresTest();
   return test;
endmodule                         

module [CONNECTED_MODULE] mkWiFiFPGAPacketGenWiresTestClocks#(Clock viterbiClock, Reset viterbiReset) ();   
   // state elements
   let transceiver <- mkBusTransceiver(viterbiClock, viterbiReset);
endmodule
