//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2010 Kermin Fleming, kfleming@mit.edu 
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

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_fft.bsh"
`include "asim/provides/airblue_fft_library.bsh"
`include "asim/provides/airblue_transmitter.bsh"
`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"


// The purpose of this test rig is to wire a tx pipeline to an rx pipepline 
// to ensure that we meet the line rate

//(* synthesize *)
module [CONNECTED_MODULE] mkTransceiver (Empty);
   // For now just stub the viterbi clock -- it should be generating its own.
   let clk <- exposeCurrentClock();
   let rst <- exposeCurrentReset();
    // RX/TX signals are at  20Mhz.
    UserClock clk20 <- mkSoftClock(20);

   let wifiFFTTX <- mkWiFiFFTIFFT;
   let wifiFFTRX <- mkWiFiFFTIFFT;
   let wifiTransmitter <- mkWiFiTransmitter(wifiFFTTX.ifft);
  let wifiReceiver    <- mkWiFiReceiver(clk, rst, wifiFFTRX.fft);

   // Soft connections to the rest of the world
   /////
   // Transmitter Connections
   /////
   Connection_Receive#(TXVector) txVector <- mkConnection_Receive("TXData");
   Connection_Receive#(Bit#(8))  txData   <- mkConnection_Receive("TXVector");
   Connection_Receive#(Bit#(1))  txEnd    <- mkConnection_Receive("TXEnd");
 
   SyncFIFOIfc#(TXVector) lengthFIFO <- mkSyncFIFOFromCC(16,clk20.clk);
 
   rule handleLength;
     txVector.deq;
     lengthFIFO.enq(txVector.receive);
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



    SyncFIFOIfc#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) txfifo <- mkSyncFIFOFromCC(32, clk20.clk);  
    SyncFIFOIfc#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) rxfifo <- mkSyncFIFOToCC(32, clk20.clk, clk20.rst);  
    Wire#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) dataTrans <- mkDWire(unpack(15),clocked_by(clk20.clk), reset_by(clk20.rst));
    PulseWire rxSunkData <- mkPulseWire(clocked_by(clk20.clk), reset_by(clk20.rst));
    PulseWire txProduceData <- mkPulseWire(clocked_by(clk20.clk), reset_by(clk20.rst));
    Reg#(Bool) last <- mkReg(False);
    Reg#(Bool) lastLast <- mkReg(False);
    Reg#(Bit#(32)) count20 <- mkReg(0, clocked_by(clk20.clk), reset_by(clk20.rst));
    Reg#(Bit#(32)) count <- mkReg(0);
    Reg#(Bit#(17)) bitCount <- mkReg(0, clocked_by(clk20.clk), reset_by(clk20.rst)); 
    Reg#(Bit#(7))  chipCount <- mkReg(0, clocked_by(clk20.clk), reset_by(clk20.rst));
    Reg#(Bit#(16))  preambleCount <- mkReg(0, clocked_by(clk20.clk), reset_by(clk20.rst));

    // Need a check to make sure TX is producing stuff at line rate
    // Let's do a glitch check
    rule txConnection;
      let data <- wifiTransmitter.out.get;
  //    $display("TX Data:%h",{pack(data)[23:16],pack(data)[31:24],pack(data)[7:0],pack(data)[15:8]});
      txfifo.enq(data);     
    endrule

    rule handleTX(!(bitCount == 0 && preambleCount == 0));
      dataTrans <= txfifo.first;
      txfifo.deq;
      txProduceData.send;
    endrule

    rule setTX(bitCount == 0 && preambleCount == 0);
      Bit#(16) preamble_sz = getPreambleCount(lengthFIFO.first.header.has_trailer);
      Bit#(17) bit_length  = getBitLength(lengthFIFO.first.header.length);
      preambleCount <= preamble_sz;  // header is 24 bits and always sent as basic rate
      bitCount <= bit_length; // bit length
      chipCount <= 0;
//      $display("Preamble Count: %h,  bit count %h", bit_length, preamble_sz);
      $display("Starting Packet");
    endrule

    rule testTX(bitCount > 0);
      if((preambleCount <  getPreambleCount(lengthFIFO.first.header.has_trailer)) &&
         !txProduceData)
        begin
          // Here we die. 
          $display("TX side failed to produce data fast enough");
          $finish;
        end
      else if(txProduceData) 
        begin
  //        $display("Preamble Count: %h,  bit count %h",  preambleCount, bitCount);
          if(preambleCount > 0)
            begin
       	      preambleCount <= preambleCount - 1;
            end
          else if(chipCount + 1 == fromInteger(valueof(SymbolLen)))
       	    begin
              chipCount <= 0;
              // we may have pad bits.  the last subtraction may not equal zero
              if(bitCount <= fromInteger(bitsPerSymbol(lengthFIFO.first.header.rate)))
                begin
                  // at this point we should send the deq pulse
                  bitCount <= 0;
                  lengthFIFO.deq;
   	        /*  if(`DEBUG_RF_DEVICE == 1)
                   begin
                     $display("AD: length done @ $d",count20);
                   end*/
                end
              else
                begin
/*                  if(`DEBUG_RF_DEVICE == 1)
                    begin
                      $display("AD: substraction");
                    end*/
                 bitCount <= bitCount - fromInteger(bitsPerSymbol(lengthFIFO.first.header.rate));
               end
          end
        else
          begin
            chipCount <= chipCount + 1;
          end
       end
    endrule





    // This rule _must_ fire every cycle
    rule handleRX;
      rxSunkData.send;
//      $display("RX data: %h", dataTrans);
      rxfifo.enq(dataTrans);
    endrule

    rule stepCount;
      count <= count + 1;
    endrule

    rule stepCount20;
      count20 <= count20 + 1;
    endrule

    rule checkRX(!rxSunkData && count20 > 1000);
      $display("RX failed to sink data");
      $finish;
    endrule

    if(`DEBUG_RXCTRL == 1)
      begin
        mkConnectionThroughput("Synchronizer",toGet(rxfifo),wifiReceiver.in);
      end
    else
      begin
        mkConnection(toGet(rxfifo),wifiReceiver.in);
      end

endmodule


