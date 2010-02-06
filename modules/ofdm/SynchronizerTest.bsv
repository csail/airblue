import FixedPoint::*;
import Complex::*;

import ofdm_common::*;
import ofdm_parameters::*;
import ofdm_preambles::*;
import ofdm_synchronizer_params::*;
import ofdm_synchronizer_library::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*; 
import ofdm_synchronizer::*;

import Vector::*;
import RegFile::*;
import GetPut::*;

// (* synthesize *)
module mkSynchronizerTest(Empty);

   // states
   Synchronizer#(RXFPIPrec,RXFPFPrec) synchronizer <- mkSynchronizer();
   
   Reg#(Bit#(10)) inCounter <- mkReg(0);
   Reg#(Bit#(10)) outCounter <- mkReg(0);
   
   // constant
   let packet <- mkPacket();
   let tweakedPacket <- mkTweakedPacket();
   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule toSynchronizer(True);
   begin
      FPComplex#(RXFPIPrec,RXFPFPrec) inCmplx = tweakedPacket.sub(inCounter);
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



