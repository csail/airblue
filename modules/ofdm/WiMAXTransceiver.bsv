import Connectable::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

import ofdm_parameters::*;
import ofdm_preambles::*;
import ofdm_tx_controller::*;
import ofdm_transmitter::*;
import ofdm_rx_controller::*;
import ofdm_receiver::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;
import ofdm_common::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import Parameters::*;
// import Receiver::*;
// import Transmitter::*;
// import WiMAXRXController::*;
// import WiMAXTXController::*;

interface WiMAXTransmitter;
   method Action txStart(TXVector txVec);    // fromMAC 
   method Action txData(Bit#(8) inData);    // fromMAC
   method Action txEnd();                    // fromMAC
   interface Get#(DACMesg#(TXFPIPrec,TXFPFPrec)) out; // to DAC
endinterface
      
interface WiMAXReceiver;
   interface Put#(RXFeedback) inFeedback;
   interface Put#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) in;
   interface Get#(Bit#(11)) outLength;
   interface Get#(Bit#(8))  outData;
endinterface

(* synthesize *)
module mkWiMAXTransmitter(WiMAXTransmitter);
   // state element
   let tx_controller <- mkWiMAXTXController;
   let transmitter <- mkTransmitterInstance;
   
   // make connection
   mkConnection(tx_controller.out,transmitter.in);
   
   // methods
   method Action txStart(TXVector txVec);
      tx_controller.txStart(txVec);
   endmethod
   
   method Action txData(Bit#(8) inData);
      tx_controller.txData(inData);
   endmethod
   
   method Action txEnd();
      tx_controller.txEnd;
   endmethod
   
   interface out = transmitter.out;
endmodule

(* synthesize *)
module mkWiMAXReceiver(WiMAXReceiver);
   // state elements
   let rx_controller <- mkWiMAXRXController;
   let receiver_preFFT <- mkReceiverPreFFTInstance;
   let receiver_preDescrambler <- mkReceiverPreDescramblerInstance;
   let descrambler <- mkDescramblerInstance;
   
   // connections
   mkConnectionPrint("PreFFT -> RXCtrl0",receiver_preFFT.out,rx_controller.inFromPreFFT);
   mkConnectionPrint("RXCtrl0 -> PreDesc",rx_controller.outToPreDescrambler,receiver_preDescrambler.in);
   mkConnectionPrint("PreDesc -> RXCtrl1",receiver_preDescrambler.out,rx_controller.inFromPreDescrambler);
   mkConnectionPrint("RXCtrl1 -> Desc",rx_controller.outToDescrambler,descrambler.in);
   mkConnectionPrint("Desc -> RXCtrl2",descrambler.out,rx_controller.inFromDescrambler);
   
   // methods
   interface inFeedback = rx_controller.inFeedback;
   interface in = receiver_preFFT.in;
   interface outLength = rx_controller.outLength;
   interface outData = rx_controller.outData;
endmodule

function Rate nextRate(Rate rate);
   return case (rate)
  	     R0: R1;
 	     R1: R2;
  	     R2: R3;
  	     R3: R4;
  	     R4: R5;
 	     R5: R6;
 	     R6: R0;
	  endcase;
endfunction

(* synthesize *)
module mkSystem (Empty);
   
   // state elements
   let transmitter <- mkWiMAXTransmitter;
   let receiver    <- mkWiMAXReceiver;
   Reg#(Bit#(32)) packetNo <- mkReg(0);
   Reg#(Bit#(8))  data <- mkReg(0);
   Reg#(Rate)     rate <- mkReg(R0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   RandomGen#(64) randGen <- mkMersenneTwister(64'hB573AE980FF1134C);
   
   // rules
   rule putTXStart(True);
      let randData <- randGen.genRand;
      let newRate = nextRate(rate);
      Bit#(11) newLength = truncate(randData);
      let txVec = TXVector{rate: newRate,
			   length: newLength,
			   cpSize: CP0,
			   bsid: randData[3:0],
			   uiuc: randData[7:4],
			   fid: randData[11:8],
			   power: 0};
      rate <= newRate;
      packetNo <= packetNo + 1;
      transmitter.txStart(txVec);
      receiver.inFeedback.put(txVec);
      $display("Going to send a packet %d at rate:%d, length:%d",packetNo,newRate,newLength);
      if (packetNo == 51)
	$finish;
   endrule
   
   rule putData(True);
      data <= data + 1;
      transmitter.txData(data);
      $display("transmitter input: rate:%d, data:%h",rate,data);
   endrule
   
   rule getOutput(True);
      let mesg <- transmitter.out.get;
      receiver.in.put(mesg);
      $write("transmitter output: data:");
      fpcmplxWrite(4,mesg);
      $display("");
   endrule
   
   rule getLength(True);
      let length <- receiver.outLength.get;
      $display("Going to receiver a packet of length:%d",length);
   endrule
   
   rule getData(True);
      let outData <- receiver.outData.get;
      $display("receiver output: data:%h",outData);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 5000000)
	 $finish;
//      $display("Cycle: %d",cycle);
   endrule
endmodule



