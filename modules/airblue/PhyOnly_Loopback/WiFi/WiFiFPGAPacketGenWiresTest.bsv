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
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_CBUSVECTORCONTROLRRR.bsh"
`include "asim/provides/analog_digital.bsh"
`include "asim/provides/gain_control.bsh"
`include "asim/provides/rf_frontend.bsh"

//For the wires test we swap for two transceivers here.
module [CONNECTED_MODULE] mkBusTransceiver#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();
  Clock busClock <- exposeCurrentClock;
  Reset busReset <- exposeCurrentReset;

  // Instantiate host communications

   ServerStub_CBUSVECTORCONTROLRRR server_stub <- mkServerStub_CBUSVECTORCONTROLRRR();

  let receiverFPGA <-  mkTransceiverPacketGenFPGA(viterbiClock, viterbiReset, busClock, busReset,rfClock, rfReset, clocked_by basebandClock, reset_by basebandReset);
  let transmitterFPGA <-  mkTransceiverPacketGenFPGA(viterbiClock, viterbiReset, busClock, busReset, rfClock, rfReset, clocked_by basebandClock, reset_by basebandReset); 
  let channel <- mkChannel(clocked_by rfClock, reset_by rfReset);
  SyncBitIfc#(Bit#(1)) txPE <- mkSyncBit(basebandClock, basebandReset, rfClock);


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


 
   //Index 0 sends to Receiver 
   //Index 1 sends to Transmitter
   //This probably belongs in a dictionary
   rule handleRequestRead;
      let request <- server_stub.acceptRequest_Read();
     
      // Choose among sender and receiver
      CBus#(AvalonAddressWidth,AvalonDataWidth) cbus_ifc;
      case (request.index) 
       0: cbus_ifc = receiverFPGA.busWires; 
       1: cbus_ifc = transmitterFPGA.busWires; 
       default: cbus_ifc = receiverFPGA.busWires;  
      endcase

      let readVal <- cbus_ifc.read(truncate(pack(request.addr)));
      if(`DEBUG_TRANSCEIVER == 1)
         begin
            $display("Transceiver Read Req addr: %x value: %x", request.addr, readVal);
         end
      server_stub.sendResponse_Read(unpack(readVal));
   endrule
 
   rule handleRequestWrite;
      let request <- server_stub.acceptRequest_Write();

      // Choose among sender and receiver
      CBus#(AvalonAddressWidth,AvalonDataWidth) cbus_ifc;
      case (request.index[0]) 
       0: cbus_ifc = receiverFPGA.busWires; 
       1: cbus_ifc = transmitterFPGA.busWires;
       default: cbus_ifc = receiverFPGA.busWires;  
      endcase

      if(`DEBUG_TRANSCEIVER == 1)
        begin
          $display("Transceiver Side Write Req addr: %x value: %x", request.addr, request.data);
        end

      cbus_ifc.write(truncate(pack(request.addr)),pack(request.data));
   endrule

endmodule

module [CONNECTED_MODULE] mkWiFiFPGAPacketGenWiresTest ();
  Clock busClock <- exposeCurrentClock;
  Reset busReset <- exposeCurrentReset;
  UserClock viterbi <- mkUserClock_PLL(`CRYSTAL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,60);
  UserClock rf <- mkUserClock_PLL(`CRYSTAL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,20);

  let m <- mkBusTransceiver(viterbi.clk, viterbi.rst, busClock, busReset, rf.clk, rf.rst);
endmodule
                               
module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
   let test <- mkWiFiFPGAPacketGenWiresTest();
   return test;
endmodule                         

module [CONNECTED_MODULE] mkWiFiFPGAPacketGenWiresTestClocks#(Clock viterbiClock, Reset viterbiReset,Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();   
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;
   // state elements
   let transceiver <- mkBusTransceiver(viterbiClock, viterbiReset, basebandClock, basebandReset, rfClock, rfReset);
endmodule
