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
import Unserializer::*;

// (* synthesize *)
module mkUnserializerTest(Empty);

   // states
   Synchronizer#(2,14) synchronizer <- mkSynchronizer;
   Unserializer#(64,2,14) unserializer <- mkUnserializer;
   Reg#(Bit#(10)) inCounter <- mkReg(0);
   Reg#(Bit#(10)) outCounter <- mkReg(0);
   RegFile#(Bit#(10), FPComplex#(2,14)) tweakedPacket <- mkTweakedPacket();
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule toSynchronizer(True);
      FPComplex#(2,14) inCmplx = tweakedPacket.sub(inCounter);
      inCounter <= inCounter + 1;
      synchronizer.in.put(inCmplx);
      $write("Execute toSync at %d:",inCounter);
      cmplxWrite("("," + "," i)",fxptWrite(7),inCmplx);
      $display("");
   endrule

   rule fromSynchronizerToUnserializer(True);
      let result <- synchronizer.out.get;
      let resultCmplx = result.data;
      outCounter <= outCounter + 1;
      unserializer.in.put(result);
      $write("Execute fromSyncToUnserializer at %d:", outCounter);
      $write("new message: %d, ", result.control.isNewPacket);
      $write("cpSize: %b, ", result.control.cpSize);
      cmplxWrite("("," + ","i)",fxptWrite(7),resultCmplx);
      $display("");
   endrule
   
   rule fromUnserializer(True);
      let result <- unserializer.out.get;
      $write("new message: %d, ", result.control);
      $write("data: %h",result.data);
      $display("");
   endrule
   
   // tick
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish();
      $display("cycle: %d",cycle);
   endrule
     
endmodule   



