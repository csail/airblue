import Complex::*;
import Controls::*;
import DataTypes::*;
import FixedPoint::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import Demapper::*;
import Mapper::*;

function t idFunc (t in);
   return in;
endfunction

(* synthesize *)
module mkDemapperTest(Empty);
   
   // state elements
   Mapper#(Modulation,12,48,2,14) mapper <- mkMapper(idFunc, False);
   Demapper#(Modulation,48,12,2,14,Bit#(3)) demapper;
   demapper <- mkDemapper(idFunc, False);
   Reg#(Bit#(4))  ctrl  <- mkReg(1);
   Reg#(Bit#(12)) data  <- mkReg(0);
   Reg#(Bit#(8))  cntr  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putMapperNewCtrl(cntr==0);
      let newCtrl = (ctrl == 8) ? 1 : ctrl << 1;
      let newCntr = case (unpack(newCtrl))
		       BPSK:   3;    
		       QPSK:   7;
		       QAM_16: 15;
		       QAM_64: 23;
		    endcase;
      let mesg = Mesg { control: unpack(newCtrl),
	   	        data: data};
      mapper.in.put(mesg);
      ctrl <= newCtrl;
      cntr <= newCntr;
      data <= data + 1;
      $display("Mapper input: ctrl = %d, data:%b",newCtrl,data);
   endrule
   
   rule putMapperInput(cntr > 0);
      let mesg = Mesg { control: unpack(ctrl),
	   	        data: data};
      mapper.in.put(mesg);
      cntr <= cntr - 1;
      data <= data + 1;
      $display("Mapper input: ctrl = %d, data:%b",ctrl,data);
   endrule

   rule getMapperOutput(True);
      let mesg <- mapper.out.get;
      demapper.in.put(mesg);
      $display("Mapper output: ctrl = %d, data: %h",mesg.control,mesg.data);
   endrule
   
   rule getDemapperOutput(True);
      let mesg <- demapper.out.get;
      $display("Demapper output: ctrl = %d, data: %b",mesg.control,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




