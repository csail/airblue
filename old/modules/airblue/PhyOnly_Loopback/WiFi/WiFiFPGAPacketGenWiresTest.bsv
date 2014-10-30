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

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/client_server_utils.bsh"
`include "asim/provides/register_mapper.bsh"
`include "asim/provides/register_library.bsh"
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/provides/analog_digital.bsh"
`include "asim/provides/gain_control.bsh"
`include "asim/provides/rf_frontend.bsh"
`include "asim/provides/airblue_phy_packet_gen.bsh"


//For the wires test we swap for two transceivers here.
module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
  Clock basebandClock <- exposeCurrentClock;
  Reset basebandReset <- exposeCurrentReset;

  // Create Clocks

  UserClock viterbi <- mkSoftClock(60);
  UserClock rf <- mkSoftClock(20);

  let receiverFPGA <-  mkTransceiverPacketGenFPGA(viterbi.clk, viterbi.rst, rf.clk, rf.rst, clocked_by basebandClock, reset_by basebandReset);
  let transmitterFPGA <-  mkTransceiverPacketGenFPGA(viterbi.clk, viterbi.rst, rf.clk, rf.rst, clocked_by basebandClock, reset_by basebandReset); 

  let channel <- mkChannel(clocked_by rf.clk, reset_by rf.rst);
  SyncBitIfc#(Bit#(1)) txPE <- mkSyncBit(basebandClock, basebandReset, rf.clk);


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

  // send only if the transmitter is transmitting
  rule driveTX;
    txPE.send(transmitterFPGA.gctWires.txPE);
  endrule

  rule connectTX(txPE.read == 1);
    let sample = dacToComplex(transmitterFPGA.dacWires);
    channel.in.put(sample);
  endrule

  rule connectTXOff(txPE.read == 0);
    channel.in.put(0);
  endrule

  rule connectRX;
    let sample <- channel.out.get();
    receiverFPGA.adcWires.adcRPart(fxptToDAC(sample.rel));
    receiverFPGA.adcWires.adcIPart(fxptToDAC(sample.img));
  endrule

  // Packet Stimulus modules

  PacketGen packetGen <- mkPacketGen;
  PacketCheck packetCheck <- mkPacketCheck;

  mkConnection(packetCheck.rxVector, receiverFPGA.outRXVector);
  mkConnection(packetCheck.rxData, receiverFPGA.outRXData);

  mkConnection(transmitterFPGA.inTXData, packetGen.txData); 
  mkConnection(transmitterFPGA.inTXVector, packetGen.txVector); 
endmodule

