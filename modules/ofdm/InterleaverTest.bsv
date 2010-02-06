import Controls::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import Vector::*;
import Interleaver::*;

function t idFunc (t in);
   return in;
endfunction

function Integer interleaverGetIndex(Modulation m, Integer k);
    Integer s = 1;  
    Integer ncbps = 192;
    case (m)
      BPSK:  
	begin
	   ncbps = 192;
	   s = 1;
	end
      QPSK:  
	begin
	   ncbps = 384;
	   s = 1;
	end
      QAM_16:
	begin
	   ncbps = 768;
	   s = 2;
	end
      QAM_64:
	begin
	   ncbps = 1152;
	   s = 3;
	end
    endcase // case(m)
    Integer i = (ncbps/12) * (k%12) + k/12;
    Integer f = (i/s);
    Integer j = s*f + (i + ncbps - (12*i/ncbps))%s;
    return (k >= ncbps) ? k : j;
endfunction			  

// (* synthesize *)
module mkInterleaverTest(Empty);
   
   // state elements
   Interleaver#(Modulation,24,24,192) interleaver;
   interleaver <- mkInterleaver(idFunc, interleaverGetIndex);
   Reg#(Bit#(4))  ctrl  <- mkReg(1);
   Reg#(Bit#(24)) data  <- mkRegU;
   Reg#(Bit#(8))  cntr  <- mkReg(0);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putNewCtrl(cntr==0);
      let newCtrl = (ctrl == 8) ? 1 : ctrl << 1;
      let newCntr = case (unpack(newCtrl))
		       BPSK:   7;
		       QPSK:   15;
		       QAM_16: 31;
		       QAM_64: 47;
		    endcase;
      let mesg = Mesg { control: unpack(newCtrl),
	   	        data: data};
      interleaver.in.put(mesg);
      ctrl <= newCtrl;
      cntr <= newCntr;
      data <= data + 1;
      $display("input: ctrl = %d, data:%h",newCtrl,data);
   endrule
   
   rule putInput(cntr > 0);
      let mesg = Mesg { control: unpack(ctrl),
	   	        data: data};
      interleaver.in.put(mesg);
      cntr <= cntr - 1;
      data <= data + 1;
      $display("input: ctrl = %d, data:%h",ctrl,data);
   endrule

   rule getOutput(True);
      let mesg <- interleaver.out.get;
      $display("output: ctrl = %d, data: %h",mesg.control,mesg.data);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule




