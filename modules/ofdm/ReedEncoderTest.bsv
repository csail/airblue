import Controls::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import ReedEncoder::*;

typedef enum {R0, R1, R2, R3, R4, R5, R6} Rate deriving(Eq, Bits);

typedef struct {
    Bool newFrame;
    Rate rate;
} GlobalCtrl deriving(Eq, Bits);

//Reed Solomon:
function ReedSolomonCtrl#(8) reedSolomonControl(GlobalCtrl ctrl);
    return case (ctrl.rate) matches
               R0   : ReedSolomonCtrl{in:12, out:0};
               R1   : ReedSolomonCtrl{in:24, out:8};
               R2   : ReedSolomonCtrl{in:36, out:4};
               R3   : ReedSolomonCtrl{in:48, out:16};
               R4   : ReedSolomonCtrl{in:72, out:8};
               R5   : ReedSolomonCtrl{in:96, out:12};
               R6   : ReedSolomonCtrl{in:108, out:12};
           endcase;
endfunction

function t idFunc (t in);
   return in;
endfunction

function Rate nextRate(Rate rate);
   let res = case (rate)
		R0: R1;
		R1: R2;
		R2: R3;
		R3: R4;
		R4: R5;
		R5: R6;
		R6: R0;
		default: R0;
	     endcase;
   return res;
endfunction

// (* synthesize *)
module mkReedEncoderTest(Empty);
   
   // state elements
   ReedEncoder#(GlobalCtrl,32,32) reedEncoder;
   reedEncoder <- mkReedEncoder(reedSolomonControl);
   Reg#(GlobalCtrl)  ctrl <- mkRegU;
   Reg#(Bit#(32))    data <- mkRegU;
   Reg#(Bit#(32))    cntr <- mkReg(0);
   Reg#(Bit#(32))   cycle <- mkReg(0);
   
   rule putNewCtrl(cntr==0);
      let newCtrl = GlobalCtrl{newFrame: False, 
			       rate: nextRate(ctrl.rate)};
      let newCntr = case (newCtrl.rate)
		       R0: 11;
		       R1: 23;
		       R2: 35;
		       R3: 47;
		       R4: 71;
		       R5: 95;
		       R6: 107;
		    endcase;
      let mesg = Mesg {control: newCtrl,
	   	       data: data};
      reedEncoder.in.put(mesg);
      ctrl <= newCtrl;
      cntr <= newCntr;
      data <= data + 2;
      $display("input: ctrl = %d, data:%h",newCtrl,data);
   endrule
   
   rule putInput(cntr > 0);
      let mesg = Mesg { control: ctrl,
	   	        data: data};
      reedEncoder.in.put(mesg);
      cntr <= cntr - 1;
      data <= data + 1;
      $display("input: ctrl = %d, data:%h",ctrl,data);
   endrule

   rule getOutput(True);
      let mesg <- reedEncoder.out.get;
      $display("output: ctrl = %d, data: %h",mesg.control,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




