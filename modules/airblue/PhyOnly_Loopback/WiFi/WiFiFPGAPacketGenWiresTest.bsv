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

// import ClientServerUtils::*;
// import AvalonSlave::*;
// import AvalonCommon::*;
// import RegisterMapper::*;

// import DataTypes::*;
// import Interfaces::*;
// import ProtocolParameters::*;
// import FPGAParameters::*;
// import Transceiver::*;
// import LibraryFunctions::*;
// import FPComplex::*;
// import AD::*;
// import GCT::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_device.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/client_server_utils.bsh"
`include "asim/provides/register_mapper.bsh"

//Bool detailedDebugInfo=True;

// no. cycles to terminate (in case get into deadlock)
//`define timeout  2000000000

// no. cycles to wait before the test declare a packet is lost 
//`define waitTime 1000000

// simulation length in terms of no. packet
`define simPackets 50

// two mode transmitting and verifying transmission
//typedef enum {Transmit, Verify} OpMode deriving (Bits,Eq);

//import "BDPI" next_rate   = function Rate     nextRate(Rate maxRate);
//import "BDPI" next_length = function Bit#(32) nextLength();





//For the wires test we swap for two transceivers here.
(*synthesize*)
module [Module] mkBusTransceiver#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();
  Clock busClock <- exposeCurrentClock;
  Reset busReset <- exposeCurrentReset;
  let receiverFPGA <-  mkTransceiverPacketGenFPGA(viterbiClock, viterbiReset, busClock, busReset,rfClock, rfReset, clocked_by basebandClock, reset_by basebandReset);
  let transmitterFPGA <-  mkTransceiverPacketGenFPGA(viterbiClock, viterbiReset, busClock, busReset, rfClock, rfReset, clocked_by basebandClock, reset_by basebandReset); 
  SyncBitIfc#(Bit#(1)) txPE <- mkSyncBit(basebandClock, basebandReset, rfClock);
  Reg#(Bool) initialized <- mkReg(False);
  Reg#(Bool) pushReq <- mkReg(True);


  // We have to initialize the packet generator on the 
    Server#(AvalonRequest#(AvalonAddressWidth,AvalonDataWidth),Bit#(AvalonDataWidth)) avalonServerTx <- mkAvalonSlaveDriver(transmitterFPGA.avalonWires);
    Server#(AvalonRequest#(AvalonAddressWidth,AvalonDataWidth),Bit#(AvalonDataWidth)) avalonServerRx <- mkAvalonSlaveDriver(receiverFPGA.avalonWires);

  rule init(!initialized);
    avalonServerTx.request.put(AvalonRequest{addr:fromInteger(valueof(AddrEnablePacketGen)),data:~0,command: register_mapper::Write});
    initialized <= True;
  endrule


  rule pushPacketRx (pushReq);
    avalonServerRx.request.put(AvalonRequest{addr:fromInteger(valueof(AddrPacketsRX)),data:~0,command: register_mapper::Read});
    pushReq <= !pushReq;
  endrule

  rule pullPacketRx (!pushReq);
    let count <- avalonServerRx.response.get;
    if(count == `simPackets)
      begin
        $display("PASS"); 
        $finish;
      end
    pushReq <= !pushReq;    
  endrule

  // send only if the transmitter is transmitting
  rule driveTX;
    txPE.send(transmitterFPGA.gctWires.txPE);
  endrule  

  rule connectRXTX(txPE.read == 1);
    receiverFPGA.adcWires.adcRPart(transmitterFPGA.dacWires.dacRPart);    
    receiverFPGA.adcWires.adcIPart(transmitterFPGA.dacWires.dacIPart); 
    FPComplex#(DACIPart,DACFPart) sample;  
    sample.img = unpack({~(transmitterFPGA.dacWires.dacIPart[9]) ,truncate(transmitterFPGA.dacWires.dacIPart)}); 
    sample.rel = unpack({~(transmitterFPGA.dacWires.dacRPart[9]) ,truncate(transmitterFPGA.dacWires.dacRPart)}); 
    FPComplex#(RXFPIPrec,RXFPFPrec) sampleExt = fpcmplxSignExtend(sample);
    FPComplex#(RXFPIPrec,RXFPFPrec) sampleConj = FPComplex{rel:sampleExt.rel,img:-1*sampleExt.img};
    let magnitude = fpcmplxMult(sampleExt,sampleConj);
    $write("TXMAG: ");
    fpcmplxWrite(5,magnitude);
    $display("");
  endrule

  rule connectRXTXOff(txPE.read == 0);
    $display("AD: No transmit, sending zeros");
    receiverFPGA.adcWires.adcRPart({1'b1,0});    
    receiverFPGA.adcWires.adcIPart({1'b1,0}); 
    if((transmitterFPGA.dacWires.dacRPart !=  {1'b1,0} ||   
       transmitterFPGA.dacWires.dacIPart !=  {1'b1,0}) && transmitterFPGA.dacWires.dacModeSelect != 0) 
      begin
        $display("AD attempts to transfer non-zero data while not transmitting: %h %h %h",transmitterFPGA.dacWires.dacRPart, transmitterFPGA.dacWires.dacIPart, transmitterFPGA.dacWires.dacModeSelect);
        $finish;
      end   
  endrule

endmodule

(*synthesize*)
module mkWiFiFPGAPacketGenWiresTest ();
  Reset reset <- exposeCurrentReset;
  Clock busClock <- mkAbsoluteClock(1,5);
  Reset busReset <- mkAsyncReset(1,reset,busClock);
  Clock viterbiClock <- mkAbsoluteClock(1,25);
  Reset viterbiReset <- mkAsyncReset(1,reset,viterbiClock);
  Clock rfClock <- mkAbsoluteClock(1,50);
  Reset rfReset <- mkAsyncReset(1,reset,rfClock);
  Clock basebandClock <- mkAbsoluteClock(1,40);
  Reset basebandReset <- mkAsyncReset(1,reset,basebandClock);
  let m <- mkWiFiFPGAPacketGenWiresTestClocks(viterbiClock, viterbiReset, basebandClock, basebandReset, rfClock, rfReset, clocked_by busClock, reset_by busReset);
endmodule
                               
module mkHWOnlyApplication (Empty);
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





module [Module] mkWiFiFPGAPacketGenWiresTestClocks#(Clock viterbiClock, Reset viterbiReset,Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();   
   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;
   // state elements
   let transceiver <- mkBusTransceiver(viterbiClock, viterbiReset, basebandClock, basebandReset, rfClock, rfReset);
endmodule
