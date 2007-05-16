import Connectable::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

import Controls::*;
import DataTypes::*;
import Interfaces::*;
import Parameters::*;
import Receiver::*;
import Transmitter::*;
import WiMAXRXController::*;
import WiMAXTXController::*;

interface WiMAXTransmitter;
   method Action txStart(TXVector txVec);    // fromMAC 
   method Action txData(Bit#(8) inData);    // fromMAC
   method Action txEnd();                    // fromMAC
   interface Get#(DACMesg#(TXFPIPrec,TXFPFPrec)) out; // to DAC
endinterface
      
interface WiMAXReceiver;
   interface Put#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) in;
   interface Get#(Bit#(12)) outLength;
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
   mkConnection(receiver_preFFT.out,rx_controller.inFromPreFFT);
   mkConnection(rx_controller.outToPreDescrambler,receiver_preDescrambler.in);
   mkConnection(receiver_preDescrambler.out,rx_controller.inFromPreDescrambler);
   mkConnection(rx_controller.outToDescrambler,descrambler.in);
   mkConnection(descrambler.out,rx_controller.inFromDescrambler);
   
   // methods
   interface in = receiver_preFFT.in;
   interface outLength = rx_controller.outLength;
   interface outData = rx_controller.outData;
endmodule



