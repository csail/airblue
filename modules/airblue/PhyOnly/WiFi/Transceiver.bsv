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

import Connectable::*;
import FIFO::*;
import GetPut::*;
import CBus::*;
import ModuleCollect::*;
import LFSR::*;
import ClientServer::*;
import Clocks::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_synchronizer.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_clocks.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_phy_packet_gen.bsh"
`include "asim/provides/airblue_phy_packet_check.bsh"
`include "asim/provides/airblue_phy.bsh"

module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;

   //UserClock viterbi <- mkSoftClock(60);

   let transceiver <- mkTransceiver();

   // packet gen crap
   PacketGen packetGen <- mkPacketGen;
   PacketCheck packetCheck <- mkPacketCheck;

   // Receiver Side   
   Connection_Receive#(Bit#(1)) abortAck <- mkConnection_Receive("AbortAck");
   Connection_Send#(Bit#(1)) abortReq <- mkConnection_Send("AbortReq");
   Connection_Receive#(Bit#(8)) outData <- mkConnection_Receive("RXData");   
   Connection_Receive#(RXVector) outVector <- mkConnection_Receive("RXVector");   


   rule rxData;
      let data = outData.receive();
      outData.deq();
      packetCheck.rxData.put(data);
   endrule

   mkConnection(packetCheck.rxVector,outVector);
   
   rule connectAbortAck (True);
      packetCheck.abortAck().put(0);
      abortAck.deq();
   endrule

   rule connectAbortReq (True);
      let dont_care <- packetCheck.abortReq.get;
      abortReq.send(0);
   endrule
   // Transmitter Side
      
   Connection_Send#(TXVector) txVector <- mkConnection_Send("TXData");
   Connection_Send#(Bit#(8))  txData   <- mkConnection_Send("TXVector");
   Connection_Send#(Bit#(1))  txEnd    <- mkConnection_Send("TXEnd");
   
   rule txVecSend;
     // spread the tx vec love
      TXVector txVec <- packetGen.txVector.get;
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver: TX start");
         end
      txVector.send(txVec);
   endrule
   
   mkConnection(txData,packetGen.txData.get);   

endmodule



