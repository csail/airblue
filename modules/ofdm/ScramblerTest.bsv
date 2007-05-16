import Controls::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import Scrambler::*;

function t idFunc(t in);
   return in;
endfunction

(* synthesize *)
module mkScramblerTest(Empty);
   
   // state elements
   Scrambler#(ScramblerCtrl#(12,7),ScramblerCtrl#(12,7),12,12) scrambler;
   scrambler <- mkScrambler(idFunc,idFunc,7'b1001000);
   Reg#(Bit#(12)) data  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putInput(True);
      let mesg = Mesg { control: ScramblerCtrl
		       {bypass: 0,
			seed: (data[4:0] == 0) ? tagged Valid 127 : Invalid},
	   	        data: data};
      scrambler.in.put(mesg);
      data <= data + 1;
      $display("input: data: %b",data);
   endrule

   rule getOutput(True);
      let mesg <- scrambler.out.get;
      $display("output: data: %b",mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




