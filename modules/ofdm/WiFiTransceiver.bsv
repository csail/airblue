import Connectable::*;
import FIFO::*;
import GetPut::*;

import ofdm_parameters::*;
import ofdm_preambles::*;
import ofdm_tx_controller::*;
import ofdm_transmitter::*;
import ofdm_rx_controller::*;
import ofdm_receiver::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;


// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import Parameters::*;
// import Receiver::*;
// import Transmitter::*;
// import WiFiTXController::*;
// import WiFiRXController::*;

interface WiFiTransmitter;
   method Action txStart(TXVector txVec);    // fromMAC 
   method Action txData(Bit#(8) inData);    // fromMAC
   method Action txEnd();                    // fromMAC
   interface Get#(DACMesg#(TXFPIPrec,TXFPFPrec)) out; // to DAC
endinterface

interface WiFiReceiver;
   interface Put#(SynchronizerMesg#(RXFPIPrec,RXFPFPrec)) in;
   interface Get#(Bit#(12)) outLength;
   interface Get#(Bit#(8))  outData;
endinterface

(* synthesize *)
module mkWiFiTransmitter(WiFiTransmitter);
   // state element
   let tx_controller <- mkWiFiTXController;
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
module mkWiFiReceiver(WiFiReceiver);
   // state elements
   let rx_controller <- mkWiFiRXController;
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

(* synthesize *)
module mkSystem (Empty);
   
   let transmitter <- mkWiFiTransmitter;
   let receiver    <- mkWiFiReceiver;
   
endmodule
