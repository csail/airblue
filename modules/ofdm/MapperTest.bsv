import Controls::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import Mapper::*;

function t idFunc (t in);
   return in;
endfunction

// (* synthesize *)
module mkMapperTest(Empty);
   
   // state elements
   Mapper#(Modulation,48,48,2,14) mapper <- mkMapper(idFunc, False);
   Reg#(Bit#(4))  ctrl  <- mkReg(1);
   Reg#(Bit#(48)) data  <- mkRegU;
   Reg#(Bit#(4))  cntr  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putNewCtrl(cntr==0);
      let newCtrl = (ctrl == 8) ? 1 : ctrl << 1;
      let newCntr = case (unpack(newCtrl))
		       BPSK:   1;
		       QPSK:   3;
		       QAM_16: 7;
		       QAM_64: 11;
		    endcase;
      let mesg = Mesg { control: unpack(newCtrl),
	   	        data: data};
      mapper.in.put(mesg);
      ctrl <= newCtrl;
      cntr <= newCntr;
      data <= data + 1;
      $display("input: ctrl = %d, data:%h",newCtrl,data);
   endrule
   
   rule putInput(cntr > 0);
      let mesg = Mesg { control: unpack(ctrl),
	   	        data: data};
      mapper.in.put(mesg);
      cntr <= cntr - 1;
      data <= data + 1;
      $display("input: ctrl = %d, data:%h",ctrl,data);
   endrule

   rule getOutput(True);
      let mesg <- mapper.out.get;
      $display("output: ctrl = %d, data: %h",mesg.control,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




