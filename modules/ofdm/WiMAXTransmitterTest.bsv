import GetPut::*;

import Controls::*;
import DataTypes::*;
import FPComplex::*;
import Interfaces::*;
import Parameters::*;
import RandomGen::*;
import WiMAXTransceiver::*;

function Rate nextRate(Rate rate);
   return case (rate)
	     R0: R1;
	     R1: R2;
	     R2: R3;
	     R3: R4;
	     R4: R5;
	     R5: R6;
	     R6: R0;
	     default: R0;
	  endcase;
endfunction

function CPSizeCtrl nextCPSize(CPSizeCtrl cpSize);
   return case (cpSize)
	     CP0: CP1;
	     CP1: CP2;
	     CP2: CP3;
	     CP3: CP0;
	  endcase;
endfunction

(* synthesize *)
module mkWiMAXTransmitterTest(Empty);
   
   // state elements
   let transmitter <- mkWiMAXTransmitter;
   Reg#(Bit#(32)) packetNo <- mkReg(0);
   Reg#(Bit#(8))  data <- mkReg(0);
   Reg#(Rate)     rate <- mkReg(R0);
   Reg#(CPSizeCtrl) cpSize <- mkReg(CP0);
//   Reg#(Bit#(11)) counter <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   RandomGen#(64) randGen <- mkMersenneTwister(64'hB573AE980FF1134C);
   
   rule putTXStart(True);
      let randData <- randGen.genRand;
      let newRate = nextRate(rate);
      let newLength = randData[22:12];
      let newBSID = randData[11:8];
      let newUIUC = randData[7:4];
      let newFID  = randData[3:0];
      let txVec = TXVector{rate: newRate,
			   length: newLength,
			   bsid: newBSID,
			   uiuc: newUIUC,
			   fid:  newFID,
			   power: 0};
      rate <= newRate;
      packetNo <= packetNo + 1;
      transmitter.txStart(txVec);
      $display("Going to send a packet %d at rate:%d, length:%d,bsid:%d, uiuc:%d, fid:%d",packetNo,newRate,newLength,newBSID,newUIUC,newFID);
      if (packetNo == 51)
	$finish;
   endrule
   
   rule putData(True);
      data <= data + 1;
      transmitter.txData(data);
      $display("input: rate:%d, data:%h",rate,data);
   endrule
   
   rule getOutput(True);
      let mesg <- transmitter.out.get;
      $write("output: data:");
      fpcmplxWrite(4,mesg);
      $display("");
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 500000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
endmodule

