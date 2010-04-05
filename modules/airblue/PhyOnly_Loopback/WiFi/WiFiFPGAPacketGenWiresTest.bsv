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
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_device.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/client_server_utils.bsh"
`include "asim/provides/register_mapper.bsh"
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/fpga_components.bsh"
`include "asim/provides/clocks_device.bsh"

`include "asim/rrr/remote_client_stub_SIMPLEHOSTCONTROLRRR.bsh"

//For the wires test we swap for two transceivers here.
module [CONNECTED_MODULE] mkBusTransceiver#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();
  Clock busClock <- exposeCurrentClock;
  Reset busReset <- exposeCurrentReset;

  // Instantiate host communications

  ClientStub_SIMPLEHOSTCONTROLRRR client_stub <- mkClientStub_SIMPLEHOSTCONTROLRRR();

  let receiverFPGA <-  mkTransceiverPacketGenFPGA(viterbiClock, viterbiReset, busClock, busReset,rfClock, rfReset, clocked_by basebandClock, reset_by basebandReset);
  let transmitterFPGA <-  mkTransceiverPacketGenFPGA(viterbiClock, viterbiReset, busClock, busReset, rfClock, rfReset, clocked_by basebandClock, reset_by basebandReset); 
  let channel <- mkChannel(clocked_by rfClock, reset_by rfReset);
  SyncBitIfc#(Bit#(1)) txPE <- mkSyncBit(basebandClock, basebandReset, rfClock);


  // We have to initialize the packet generator on the 
  Server#(AvalonRequest#(AvalonAddressWidth,AvalonDataWidth),Bit#(AvalonDataWidth)) avalonServerTx <- mkAvalonSlaveDriver(transmitterFPGA.avalonWires);
  Server#(AvalonRequest#(AvalonAddressWidth,AvalonDataWidth),Bit#(AvalonDataWidth)) avalonServerRx <- mkAvalonSlaveDriver(receiverFPGA.avalonWires);

  function AvalonRequest#(AvalonAddressWidth,AvalonDataWidth) readRequest(Integer addr);
    return AvalonRequest{addr:fromInteger(addr),data:~0,command: register_mapper::Read};
  endfunction

  Reg#(Bool) finished <- mkReg(False);
  Reg#(Rate) rate <- mkReg(R0);
  Stmt stmt =
    (seq
      // set the test rate 
      client_stub.makeRequest_GetRate(?);
      action
        let rateBits <- client_stub.getResponse_GetRate();
        rate <= unpack(truncate(rateBits));
      endaction
      $display("Rate %d", rate);
      avalonServerTx.request.put(AvalonRequest{addr:fromInteger(valueof(AddrRate)),data:zeroExtend(pack(rate)),command: register_mapper::Write});
      // enable packet gen
      avalonServerTx.request.put(AvalonRequest{addr:fromInteger(valueof(AddrEnablePacketGen)),data:~0,command: register_mapper::Write});
      
      // wait until simPackets are received
      while (!finished)
      seq
        avalonServerRx.request.put(readRequest(valueof(AddrPacketsRX)));
        action
          let count <- avalonServerRx.response.get;
          finished <= (count == `SIM_PACKETS);
        endaction
      endseq

      // get the BER
      avalonServerRx.request.put(readRequest(valueof(AddrBER)));
      action
        let ber <- avalonServerRx.response.get;
        $display("BER total: %d", ber);
        client_stub.makeRequest_CheckBER(ber);
      endaction
      action
        let checkResult <- client_stub.getResponse_CheckBER();
        if (checkResult == 1)
          begin
            $display("PASS");
            $finish(0);
          end
        else
          begin
            $display("FAIL");
          $finish(1);
          end
        endaction
    endseq);


  // Instantiate FSM
  mkAutoFSM(stmt);


  function FPComplex#(2,14) dacToComplex(DACWires dac);
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

endmodule

module [CONNECTED_MODULE] mkWiFiFPGAPacketGenWiresTest ();
  Reset reset <- exposeCurrentReset;
  Clock busClock <- exposeCurrentClock;
  Reset busReset <- exposeCurrentReset;
  UserClock viterbi <- mkUserClock_PLL(`CRYSTAL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,60);
  UserClock rf <- mkUserClock_PLL(`CRYSTAL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,20);
  UserClock baseband <- mkUserClock_PLL(`CRYSTAL_CLOCK_FREQ*`MODEL_CLOCK_MULTIPLIER/`MODEL_CLOCK_DIVIDER,40);

  let m <- mkWiFiFPGAPacketGenWiresTestClocks(viterbi.clk, viterbi.rst, baseband.clk, baseband.rst, rf.clk, rf.rst, clocked_by busClock, reset_by busReset);
endmodule
                               
module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
   let test <- mkWiFiFPGAPacketGenWiresTest();
   return test;
endmodule                         
                               
function Reg#(regType) mkRegFromActions(function regType readAction(), function Action writeAction(regType value));
  Reg#(regType) regIfc = interface Reg;
                           method regType _read();
                             return readAction;
                           endmethod
 
                           method Action _write(regType value);
                             writeAction(value);
                           endmethod
                         endinterface;
  return regIfc;
endfunction


module [CONNECTED_MODULE] mkWiFiFPGAPacketGenWiresTestClocks#(Clock viterbiClock, Reset viterbiReset,Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();   
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;
   // state elements
   let transceiver <- mkBusTransceiver(viterbiClock, viterbiReset, basebandClock, basebandReset, rfClock, rfReset);
endmodule
