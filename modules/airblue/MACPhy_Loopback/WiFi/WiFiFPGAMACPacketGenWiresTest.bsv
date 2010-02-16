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

// import ClientServerUtils::*;
// import AvalonSlave::*;
// import AvalonCommon::*;
// import CBusUtils::*;

// import DataTypes::*;
// import Interfaces::*;
// import ProtocolParameters::*;
// import FPGAParameters::*;
// import Transceiver::*;
// import LibraryFunctions::*;
// import FPComplex::*;
// import AD::*;
// import GCT::*;
// import MACDataTypes::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_device.bsh"
`include "asim/provides/avalon.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/client_server_utils.bsh"

// Bool detailedDebugInfo=True;


// // no. cycles to terminate (in case get into deadlock)
// `define timeout  2000000000

// // no. cycles to wait before the test declare a packet is lost 
// `define waitTime 4000000

// simulation length in terms of no. packet
`define simPackets 10

typedef 4 NumMACs;

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


(*synthesize*)
module mkBusMacVectorSpec#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) (BusMac#(NumMACs));
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

module [Module] mkBusMacVector#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) (BusMac#(numMAC))
  provisos(Add#(1,a,numMAC));
  Clock busClock <- exposeCurrentClock;
  Reset busReset <- exposeCurrentReset; 
  Vector#(numMAC,TransceiverFPGA) transceivers <-  replicateM(mkTransceiverMACPacketGenFPGA(viterbiClock, viterbiReset,busClock, busReset,rfClock, rfReset, clocked_by basebandClock, reset_by basebandReset));
  Vector#(numMAC,MAC) indirectMACs = newVector;

  Vector#(numMAC,SyncBitIfc#(Bit#(1))) txPEVec <- replicateM(mkSyncBit(basebandClock, basebandReset, rfClock));
  Vector#(numMAC,Reg#(Bool)) putAddrLocalVec <- replicateM(mkReg(False));
  Vector#(numMAC,Reg#(Bool)) putAddrTargetVec <- replicateM(mkReg(False));
  Vector#(numMAC,Reg#(Bit#(16))) addrCountVec <- replicateM(mkReg(~0)); // use this to give all the mac addrs time to settle out.
  Reg#(Bit#(16)) count <- mkReg(~0);
  Reg#(Bit#(64)) ticks <- mkReg(0);
  Reg#(Bool) collision <- mkReg(False, clocked_by rfClock, reset_by rfReset);
  Reg#(Bit#(32)) collisionCounter <- mkReg(0, clocked_by rfClock, reset_by rfReset);
  Reg#(Bit#(32)) slowCycles <- mkReg(0, clocked_by rfClock, reset_by rfReset);

   rule ticksUp;
     ticks <= ticks + 1;
   endrule
 
   rule tickCount (count != 0);
     count <= count - 1;
   endrule

  for(Integer i = 0; i < valueof(numMAC); i = i+1)
    begin
      Server#(AvalonRequest#(AvalonAddressWidth,AvalonDataWidth),Bit#(AvalonDataWidth)) avalonServer <- mkAvalonSlaveDriver(transceivers[i].avalonWires);
      Vector#(3,Server#(AvalonRequest#(AvalonAddressWidth,AvalonDataWidth),Bit#(AvalonDataWidth))) servers <- mkReplicatedServer(avalonServer,50);
      // notice we use only the last 2   
      Vector#(2,AvalonSlaveDriverCBusWrapper#(AvalonAddressWidth,AvalonDataWidth)) serverFunctions <- mapM(mkAvalonSlaveDriverCBusWrapper,take(servers)); 
      Put#(Bit#(48)) addrLocalPut <- mkMarshalCBusPut(valueof(MACAddrOffset),1,serverFunctions[1].putBusRequest, serverFunctions[1].getBusResponse);
      Put#(Bit#(48)) addrTargetPut <- mkMarshalCBusPut(valueof(TargetMACAddrOffset),1,serverFunctions[0].putBusRequest, serverFunctions[0].getBusResponse);
      Reg#(Bool) initialized <- mkReg(False);
      Reg#(Bool) pushReq <- mkReg(True);
     

      
      // need some fold function here.
      rule init(!initialized && pushReq && fold(logicAnd,map(eq(0),readVReg(addrCountVec))));
        servers[2].request.put(AvalonRequest{addr:fromInteger(valueof(AddrEnablePacketGen)),data:~0,command: register_mapper::Write});
       
        $display("TB initializing MAC %d",i);
        pushReq <= !pushReq;    
      endrule

      rule takeResp(!initialized && !pushReq);
        let count <- servers[2].response.get;
        initialized <= True;
        pushReq <= !pushReq;    
      endrule
      // count packets acked, not RXed
      rule pushPacketRx (initialized && pushReq);
        servers[2].request.put(AvalonRequest{addr:fromInteger(valueof(AddrPacketsAcked)),data:~0,command: register_mapper::Read});
        pushReq <= !pushReq;
//        $display("TB PacketGen pushReq");
      endrule

      rule pullPacketRx (initialized && !pushReq);
        let count <- servers[2].response.get;
  //      $display("TB PacketGen pullReq %d", count);
        if(count >= `simPackets)
          begin
            $display("MAC PASS at %d, count: %h", ticks, count); //100Mhz cycles.
            $finish;
          end 
        pushReq <= !pushReq;    
      endrule


      rule driveTX;
        txPEVec[i].send(transceivers[i].gctWires.txPE);
      endrule  

        
      rule setAddrLocal(!putAddrLocalVec[i]);
        putAddrLocalVec[i] <= True;
        $display("MAC TB %d addr vec local set",i);
        addrLocalPut.put(fromInteger(i*7+15));
      endrule

      rule setAddrTarget(!putAddrTargetVec[i]);
        putAddrTargetVec[i] <= True;
        $display("MAC TB %d addr target vec set",i);
        addrTargetPut.put((i==valueof(NumMACs)-1)?15:fromInteger((i+1)*7+15));
      endrule
      
      rule countDown(putAddrLocalVec[i] && putAddrTargetVec[i] && addrCountVec[i] != 0 );
        if(addrCountVec[i] == 1)
          begin
           $display("MAC TB %d starting addr count",i);
          end
        addrCountVec[i] <= addrCountVec[i] - 1;  
      endrule

    end 




  rule modelChannel;

    // sum up the channels.

    FPComplex#(DACIPart,DACFPart) sample;  
    sample.img = 0;
    sample.rel = 0;
   
    Integer on = 0;

    slowCycles <= slowCycles + 1;

    for(Integer i = 0; i < valueof(numMAC); i = i+1)
      begin
        if(txPEVec[i].read == 1)
          begin
            on = on + 1;
            FPComplex#(DACIPart,DACFPart) sampleLocal;  
            sampleLocal.img = unpack({~(transceivers[i].dacWires.dacIPart[9]) ,truncate(transceivers[i].dacWires.dacIPart)}); 
            sampleLocal.rel = unpack({~(transceivers[i].dacWires.dacRPart[9]) ,truncate(transceivers[i].dacWires.dacRPart)}); 
            sample = sample+sampleLocal;
          end
      end

    if(on > 1) 
      begin
        collision <= True;  
        if(!collision)
          begin
            $display("TB MAC CW Collisions Upped: %d at %d cycles", collisionCounter+1,slowCycles);
            collisionCounter <= collisionCounter + 1;
          end
      end
    else
      begin
        collision <= False;
      end

    // cannot combine these loops
    for(Integer i = 0; i < valueof(numMAC); i = i+1)
      begin
        if(txPEVec[i].read == 0)
          begin
            Bit#(10) img = pack(sample.img);
            Bit#(10) rel = pack(sample.rel);
            transceivers[i].adcWires.adcRPart({~rel[9],truncate(rel)});    
            transceivers[i].adcWires.adcIPart({~img[9],truncate(img)});    
          end
      end
   
    FPComplex#(RXFPIPrec,RXFPFPrec) sampleExt = fpcmplxSignExtend(sample);
    $display("TXDATASrc!!!: hex: %h   ", sampleExt);
  endrule

  
  interface macs = indirectMACs;
endmodule

// Use sequence number as a drop criterion.

(*synthesize*)
module mkWiFiFPGAMACPacketGenWiresTest ();
  Reset reset <- exposeCurrentReset;
  Clock busClock <- mkAbsoluteClock(1,10);
  Reset busReset <- mkAsyncReset(1,reset,busClock);
  Clock rfClock <- mkAbsoluteClock(1,50);
  Clock viterbiClock <- mkAbsoluteClock(1,25);
  Reset viterbiReset <- mkAsyncReset(1,reset,viterbiClock);
  Reset rfReset <- mkAsyncReset(1,reset,rfClock);
  Clock basebandClock <- mkAbsoluteClock(1,40);
  Reset basebandReset <- mkAsyncReset(1,reset,basebandClock);
  let m <- mkWiFiFPGAMACTestClocks(viterbiClock, viterbiReset,basebandClock, basebandReset, rfClock, rfReset, clocked_by busClock, reset_by busReset);
endmodule

module mkHWOnlyApplication (Empty);
   let test <- mkWiFiFPGAMACPacketGenWiresTest(); 
endmodule

// XXX may need to check that we are forwarding data in time.
// we will periodically insert errors in the stream.
// we will blindly retransmit each packet until we confirm reception.
module [Module] mkWiFiFPGAMACTestClocks#(Clock viterbiClock, Reset viterbiReset, Clock basebandClock, Reset basebandReset, Clock rfClock, Reset rfReset) ();
   

   Clock clock <- exposeCurrentClock;
   Reset reset <- exposeCurrentReset;
   Reg#(Bit#(32))   cycle        <- mkReg(0);

   let               wifiMacs <- mkBusMacVectorSpec(viterbiClock, viterbiReset, basebandClock, basebandReset, rfClock, rfReset);

endmodule


