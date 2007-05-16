import DataTypes::*;
import Interfaces::*;
import Synchronizer::*;
import FixedPoint::*;
import Complex::*;
import Preambles::*;
import SynchronizerLibrary::*;
import Vector::*;
import RegFile::*;
import FPComplex::*;
import GetPut::*;
import Controls::*;

(* synthesize *)
module mkSynchronizerTest(Empty);

   // states
   Synchronizer#(2,14) synchronizer <- mkSynchronizer();
   
   Reg#(Bit#(10)) inCounter <- mkReg(0);
   Reg#(Bit#(10)) outCounter <- mkReg(0);
   
   // constant
   RegFile#(Bit#(10),FPComplex#(2,14)) packet <- mkPacket();
   RegFile#(Bit#(10), FPComplex#(2,14)) tweakedPacket <- mkTweakedPacket();
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule toSynchronizer(True);
   begin
      FPComplex#(2,14) inCmplx = tweakedPacket.sub(inCounter);
      inCounter <= inCounter + 1;
      synchronizer.in.put(inCmplx);
      $write("Execute toSync at %d:",inCounter);
      cmplxWrite("("," + "," i)",fxptWrite(7),inCmplx);
      $display("");
   end
   endrule

   rule fromSynchronizerToUnserializer(True);
   begin
      let result <- synchronizer.out.get;
      let resultCmplx = result.data;
      outCounter <= outCounter + 1;
      $write("Execute fromSyncToUnserializer at %d:", outCounter);
      $write("new message: %d, ", result.control.isNewPacket);
      cmplxWrite("("," + ","i)",fxptWrite(7),resultCmplx);
      $display("");
      $write("Expected Output at %d:", outCounter);
      cmplxWrite("("," + ","i)",fxptWrite(7),packet.sub(outCounter));
      $display("");
   end
   endrule
   
   // tick
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish();
      $display("cycle: %d",cycle);
   endrule
     
endmodule   



