//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2008 Alfred Man Cheuk Ng, mcn02@mit.edu 
//                    Kermin Fleming,kfleming @mit.edu
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
import RegFile::*;
import Complex::*;
import FixedPoint::*;
import FIFOF::*;
import FIFO::*;
import GetPut::*;


// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/client_server_utils.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_CBUSVECTORCONTROLRRR.bsh"

// Bool detailedDebugInfo=True;


// // no. cycles to terminate (in case get into deadlock)
// `define timeout  2000000000

// // no. cycles to wait before the test declare a packet is lost 
// `define waitTime 4000000

// simulation length in terms of no. packet
`define simPackets 10

typedef 2 NumMACs;

function Bool andFunc(Bool a, Bool b);
  return a && b;
endfunction

function Bool eqFunc(data a, data b)
  provisos(Eq#(data));
  return a == b;
endfunction

interface BusMac#(numeric type num);
  interface Vector#(num,MAC) macs;
endinterface


module [CONNECTED_MODULE] mkBusMacVectorSpec#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) (BusMac#(NumMACs));
 let m <- mkBusMacVector(viterbiClock, viterbiReset, basebandClock, basebandReset, rfClock, rfReset);
 return m;
endmodule

//For the wires test we swap for two transceivers here.

function Bool eq(data a, data b)
  provisos(Eq#(data));
  return a == b;
endfunction

function Bool logicAnd(Bool a, Bool b);
  return a && b;
endfunction

module [CONNECTED_MODULE] mkBusMacVector#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) (BusMac#(numMAC))
  provisos(Add#(2,a,numMAC));

   Clock busClock <- exposeCurrentClock;
   Reset busReset <- exposeCurrentReset;

   ServerStub_CBUSVECTORCONTROLRRR server_stub <- mkServerStub_CBUSVECTORCONTROLRRR();

   Vector#(numMAC,TransceiverFPGA) transceivers <- replicateM(
      mkTransceiverMACPacketGenFPGA(viterbiClock, viterbiReset,
         busClock, busReset, rfClock, rfReset,
         clocked_by basebandClock, reset_by basebandReset));

   Vector#(numMAC,MAC) indirectMACs = newVector;

   Vector#(numMAC,SyncBitIfc#(Bit#(1))) txPEVec <- replicateM(
      mkSyncBit(basebandClock, basebandReset, rfClock));

   Vector#(2,Channel#(2,14)) channels <- replicateM(
      mkChannel(clocked_by rfClock, reset_by rfReset));

   function FPComplex#(2,14) dacToComplex(DAC_WIRES dac);
     let in = FPComplex {
       rel: FixedPoint {
         i: ~dac.dacRPart[9],
         f: dac.dacRPart[8:0]
       },
       img: FixedPoint {
         i: ~dac.dacIPart[9],
         f: dac.dacIPart[8:0]
       }
     };
 
     return fpcmplxSignExtend(in);
   endfunction
 
   function Bit#(10) fxptToDAC(FixedPoint#(2,14) sample);
     FixedPoint#(1,9) trunc = fxptTruncate(sample);
     Bit#(10) out = pack(trunc);
     return { ~out[9], out[8:0] };
   endfunction

   for (Integer i = 0; i < 2; i = i+1)
     begin
       let txPE = txPEVec[i];
       let transmitterFPGA = transceivers[i];
       let receiverFPGA = transceivers[i == 0 ? 1 : 0];

       messageM("txPE reset == transmitterFPGA.gctWires.txPE reset: " + 
                (resetOf(txPE) == resetOf(transmitterFPGA.gctWires.txPE) ?
                "True" : "False"));

       // send only if the transmitter is transmitting
       rule driveTX;
         txPE.send(transmitterFPGA.gctWires.txPE);
       endrule
 
       rule connectTX(txPE.read == 1);
         let sample = dacToComplex(transmitterFPGA.dacWires);
         channels[i].in.put(sample);
       endrule
 
       rule connectTXOff(txPE.read == 0);
         channels[i].in.put(0);
       endrule

       rule connectRX;
         let sample <- channels[i].out.get();
         receiverFPGA.adcWires.adcRPart(fxptToDAC(sample.rel));
         receiverFPGA.adcWires.adcIPart(fxptToDAC(sample.img));
       endrule
     end

   function CBus#(AvalonAddressWidth,AvalonDataWidth) transceiverBus(Bit#(32) idx);
      CBus#(AvalonAddressWidth,AvalonDataWidth) cbus_ifc = transceivers[0].busWires;
      for(Integer i = 1; i < valueof(numMAC); i = i+1)
         if (idx == fromInteger(i))
            cbus_ifc = transceivers[i].busWires;
      return cbus_ifc;
   endfunction

   rule handleRequestRead;
      let request <- server_stub.acceptRequest_Read();
     
      let cbus_ifc = transceiverBus(request.index);
      let readVal <- cbus_ifc.read(truncate(pack(request.addr)));

      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver Read Req addr: %x value: %x", request.addr, readVal);
         end

      server_stub.sendResponse_Read(unpack(readVal));
   endrule

   rule handleRequestWrite;
      let request <- server_stub.acceptRequest_Write();

      if(`DEBUG_TRANSCEIVER == 1)
        begin
          $display("Transceiver Side Write Req addr: %x value: %x", request.addr, request.data);
        end

      let cbus_ifc = transceiverBus(request.index);
      cbus_ifc.write(truncate(pack(request.addr)),pack(request.data));
   endrule

  
  interface macs = indirectMACs;
endmodule

// Use sequence number as a drop criterion.

module [CONNECTED_MODULE] mkWiFiFPGAMACPacketGenWiresTest ();
  Clock busClock <- exposeCurrentClock;
  Reset busReset <- exposeCurrentReset;

  // If the MAC expects a different microsecond count than what we 
  // are giving it, the mac will simply not function. So we should 
  // check.

  if(`MODEL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER !=
     valueof(TicksPerMicrosecond))
    errorM("Model frequency is not what MAC expects.  Please fix it.");

  UserClock viterbi <- mkUserClock_PLL(`MODEL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,60);
  UserClock rf <- mkUserClock_PLL(`MODEL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,20);
 
 let m <- mkWiFiFPGAMACTestClocks(viterbi.clk, viterbi.rst, busClock, busReset,
                                  rf.clk, rf.rst);
endmodule

module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
   let test <- mkWiFiFPGAMACPacketGenWiresTest(); 
endmodule

// XXX may need to check that we are forwarding data in time.
// we will periodically insert errors in the stream.
// we will blindly retransmit each packet until we confirm reception.
module [CONNECTED_MODULE] mkWiFiFPGAMACTestClocks#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();
   

   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;
   Reg#(Bit#(32))   cycle        <- mkReg(0);

   let               wifiMacs <- mkBusMacVectorSpec(viterbiClock, viterbiReset, basebandClock, basebandReset, rfClock, rfReset);

endmodule


