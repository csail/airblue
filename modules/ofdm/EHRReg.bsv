//////////////////////////////////////////////////////////
// Interface: EHRReg#(sz, data_t)
// Description: create a EHRReg of data_t with sz read 
//              and write ports, the scheduling is
//              read0 < write0 < read1 < write1 < ....
//
// Module: mkEHRReg(data_t init)
// Description: create the EHRReg with init as initial value              
/////////////////////////////////////////////////////////

import RWire::*;
import Vector::*;

interface VRead#(type a);
   method a read();
endinterface

interface EHR#(type a);
   interface VRead#(a) vRead; 
   interface Reg#(a)   vReg;
endinterface
  
typedef Vector#(sz, Reg#(a)) EHRReg#(numeric type sz, type a);

module mkVRead#(Reg#(a) first)
  (VRead#(a)) provisos (Bits#(a,asz));

   method a read();
     return first;
   endmethod
   
endmodule // mkVRead


module mkEHR#(VRead#(a) last) 
  (EHR#(a)) provisos (Bits#(a,asz));

   RWire#(a) rwire <- mkRWire;

   interface VRead vRead;
      method a read();
         let res = (isValid(rwire.wget)) ? 
		   fromMaybe(?,rwire.wget) :
		   last.read;
         return res;
      endmethod
   endinterface 	
     
   interface Reg vReg;
      method Action _write(a x);
         rwire.wset(x);
      endmethod
	
      method a _read();
         return last.read;
      endmethod
   endinterface 	
endmodule

module mkEHRReg#(a init) (EHRReg#(sz,a)) provisos (Bits#(a,asz));

   Reg#(a)             dataReg <- mkReg(init);
   VRead#(a)          fstVRead <- mkVRead(dataReg);
   Vector#(sz, EHR#(a)) ehrs = newVector;
   EHRReg#(sz, a)     ehrReg = newVector;
   ehrs[0]  <- mkEHR(fstVRead);
   ehrReg[0] = ehrs[0].vReg;
   for(Integer i = 1; i < valueOf(sz); i = i + 1)
   begin
      ehrs[i]  <- mkEHR(ehrs[i-1].vRead);
      ehrReg[i] = ehrs[i].vReg;
   end

   rule updateReg(True);
      dataReg <= ehrs[valueOf(sz)-1].vRead.read;
   endrule
   
   return ehrReg;
endmodule // mkEHRReg





