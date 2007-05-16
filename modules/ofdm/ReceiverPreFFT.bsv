import Controls::*;
import DataTypes::*;
import Interfaces::*;
import Parameters::*;
import Synchronizer::*;
import Unserializer::*;
import Connectable::*;
import GetPut::*;
import LibraryFunctions::*;

(* synthesize *)
module mkSynchronizerInstance
   (Synchronizer#(SyncIntPrec,SyncFractPrec));
   Synchronizer#(SyncIntPrec,SyncFractPrec) block <- mkSynchronizer;
   return block;
endmodule

(* synthesize *)
module mkUnserializerInstance
   (Unserializer#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec));
   Unserializer#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec) block <- mkUnserializer;
   return block;
endmodule

(* synthesize *)
module mkReceiverPreFFTInstance
   (ReceiverPreFFT#(UnserialOutDataSz,RXFPIPrec,RXFPFPrec));
   
   // state elements
   let synchronizer <- mkSynchronizerInstance;
   let unserializer <- mkUnserializerInstance;
   
   // connections
   mkConnectionPrint("Sync -> Unse",synchronizer.out,unserializer.in);
//     mkConnection(synchroinzer.out,unserializer.in);
   
   // methods
   interface in = synchronizer.in;
   interface out = unserializer.out;
endmodule
		     



