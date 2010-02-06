import Controls::*;
import CPInsert::*;
import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Interfaces::*;
import WiMAXPreambles::*;
import Vector::*;

function t idFunc (t in);
   return in;
endfunction

// (* synthesize *)
module mkCPInsertTest(Empty);
   
   // constants
   Symbol#(256,1,15) inSymbol = newVector;
   for(Integer i = 0; i < 256; i = i + 1)
      inSymbol[i] = unpack(pack(fromInteger(i)));
   
   // state elements
   CPInsert#(CPInsertCtrl,256,1,15) cpInsert; 
   cpInsert <- mkCPInsert(idFunc,
			  getShortPreambles,
			  getLongPreambles);
   Reg#(Bit#(4)) cpsz <- mkReg(1);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putInput(True);
      CPInsertCtrl ctrl = (cpsz == 1) ? 
			  tuple2(SendLong, unpack(cpsz)) :
                          tuple2(SendNone, unpack(cpsz));
      let mesg = Mesg { control:ctrl,
	   	        data: inSymbol};
      cpInsert.in.put(mesg);
      cpsz <= (cpsz == 8) ? 1: cpsz << 1;
      $display("input: cpsize = %d",cpsz);
//      joinActions(map(fpcmplxWrite(4),inSymbol));
   endrule
   
   rule getOutput(True);
      let mesg <- cpInsert.out.get;
      $display("output: %d",mesg);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
      $display("Cycle: %d",cycle);
   endrule
  
endmodule



