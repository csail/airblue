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
`include "asim/provides/airblue_phy.bsh"

module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;

   Connection_Send#(DACMesg#(TXFPIPrec,TXFPFPrec)) analogTX <- mkConnection_Send("AnalogTransmit");

   Connection_Receive#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) analogRX <- mkConnection_Receive("AnalogReceive");

   //UserClock viterbi <- mkSoftClock(60);

   WiFiTransceiver transceiver <- mkTransceiver(clock,reset);

   // packet gen crap
   PacketGen packetGen <- mkPacketGen;
   PacketCheck packetCheck <- mkPacketCheck;

   // hook the Synchronizer to feedback points  
   rule synchronizerFeedback;
     ControlType ctrl <- transceiver.receiver.synchronizerStateUpdate.get;
   endrule
   
   // connect agc/rx ctrl
   rule packetFeedback;
     RXExternalFeedback feedback <- transceiver.receiver.packetFeedback.get;
   endrule


   // Build up CReg interface   
   // Receiver Side   
   rule rxData;
      let data <- transceiver.receiver.outData.get();
      packetCheck.rxData.put(data);
   endrule

   mkConnection(packetCheck.rxVector,transceiver.receiver.outRXVector);
   mkConnection(packetCheck.abortAck,transceiver.receiver.abortAck);
   
   rule connectAbortReq (True);
      let dont_care <- packetCheck.abortReq.get;
      transceiver.receiver.abortReq;
   endrule

   // Transmitter Side
      


   mkConnection(transceiver.transmitter.out,analogTX);


   
   mkConnection(analogRX,transceiver.receiver.in); 



   rule txVecSend;
     // spread the tx vec love
      TXVector txVec <- packetGen.txVector.get;
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver: TX start");
         end
      transceiver.transmitter.txStart(txVec);
   endrule
   
   mkConnection(transceiver.transmitter.txData,packetGen.txData.get);   

endmodule



