import Controls::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import ConvEncoder::*;

(* synthesize *)
module mkConvEncoderTest(Empty);
   
   // state elements
   ConvEncoder#(Bit#(1),12,24) convEncoder;
   convEncoder<- mkConvEncoder(7'b1011011,7'b1111001);
   Reg#(Bit#(12)) data  <- mkRegU;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putInput(True);
      let mesg = Mesg { control: ?,
	   	        data: data};
      convEncoder.in.put(mesg);
      data <= data + 1;
      $display("input: data: %b",data);
   endrule

   rule getOutput(True);
      let mesg <- convEncoder.out.get;
      $display("output: data: %b",mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




