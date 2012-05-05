//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2012 Kermin Fleming, kfleming@mit.edu 
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
import Clocks::*;
import FixedPoint::*;
import Complex::*;
import Vector::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_fft.bsh"
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/airblue_fft_library.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/rrr/remote_server_stub_LOOPBACKRRR.bsh"

// The purpose of this test rig is to wire a tx pipeline to an rx pipepline 
// to ensure that we meet the line rate

//(* synthesize *)
module [CONNECTED_MODULE] mkTransceiver (Empty);
   // For now just stub the viterbi clock -- it should be generating its own.
   let clk <- exposeCurrentClock();
   let rst <- exposeCurrentReset();

   ServerStub_LOOPBACKRRR serverStub <- mkServerStub_LOOPBACKRRR();
   Reg#(FixedPoint#(16,16)) scale <- mkReg(1);
   let channel <- mkChannel;
   
   rule setScale;
     let newScale <- serverStub.acceptRequest_SetScale();
     scale <= unpack(newScale);
   endrule


   let wifiFFTTX <- mkWiFiFFTIFFT;
   let wifiFFTRX <- mkWiFiFFTIFFT;
   let wifiTransmitter <- mkWiFiTransmitter(wifiFFTTX.ifft);
   let wifiReceiver    <- mkWiFiReceiver(clk, rst, wifiFFTRX.fft);

   // Soft connections to the rest of the world
   /////
   // Transmitter Connections
   /////
   Connection_Receive#(TXVector) txVector <- mkConnection_Receive("TXVector");
   Connection_Receive#(Bit#(8))  txData   <- mkConnection_Receive("TXData");
   Connection_Receive#(Bit#(1))  txEnd    <- mkConnection_Receive("TXEnd");
 

 
   rule handleLength;
     txVector.deq;
     wifiTransmitter.txStart(txVector.receive);
   endrule

   mkConnection(txData, wifiTransmitter.txData);


   rule handleTXEnd;
     txEnd.deq;
     wifiTransmitter.txEnd();
   endrule

   /////
   // Receiver connections
   /////
   Connection_Send#(Bit#(1)) abortAck <- mkConnection_Send("AbortAck");
   Connection_Receive#(Bit#(1)) abortReq <- mkConnection_Receive("AbortReq");
   Connection_Send#(Bit#(8)) outData <- mkConnection_Send("RXData");   
   Connection_Send#(RXVector) outVector <- mkConnection_Send("RXVector");   

   mkConnection(wifiReceiver.outData, outData); 
   mkConnection(wifiReceiver.outRXVector, outVector); 

   rule handleAck;
     let ack <- wifiReceiver.abortAck.get();
     abortAck.send(0);
   endrule

   rule handleAbort;
     abortReq.deq();
     wifiReceiver.abortReq();
   endrule

   // Drop the synchronizer state updates for now - this reduces clutter above us

     // hook the Synchronizer to feedback points  
     rule synchronizerFeedback;
       let ctrl <- wifiReceiver.synchronizerStateUpdate.get;
     endrule
   
     // connect agc/rx ctrl
     rule packetFeedback;
       let feedback <- wifiReceiver.packetFeedback.get;
     endrule

    rule txConnection;
      let data <- wifiTransmitter.out.get;
      FPComplex#(2,14) dataExtend = fpcmplxTruncate(data);
      $write("Loopback TX: ");
      fpcmplxWrite(5,dataExtend);
      $display("");
      channel.in.put(dataExtend);
    endrule

    rule rxConnection;
      let sampleTrunc <- channel.out.get();
      FPComplex#(RXFPIPrec, RXFPFPrec) sample = fpcmplxSignExtend(sampleTrunc);
      $write("Loopback RX: ");
      fpcmplxWrite(5,sample);
      $display("");
      wifiReceiver.in.put(sample);  
    endrule

endmodule


