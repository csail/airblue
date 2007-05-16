import BRAM::*;
import EHRReg::*;
import FIFO::*;

module mkBRAMFIFO#(index_t lo_index, index_t hi_index) 
   (FIFO#(data_t))
   provisos (Bits#(index_t,size_index),
	     Bits#(data_t,size_data),
	     Arith#(index_t),
	     Eq#(index_t),
	     Literal#(index_t));

   // state elements
   BRAM#(index_t,data_t) bram <- mkRegFileBRAM(lo_index, hi_index);
   Reg#(index_t)         tail <- mkReg(0);
   EHRReg#(2,index_t)    head <- mkEHRReg(0);
   EHRReg#(3,Bool)       over <- mkEHRReg(False);
   
   // constants
   let notEmpty = head[0] != tail || over[0];
   let notFull  = head[1] != tail || !over[1]; 
   
   // rules
   rule putReadRequest (True);
      bram.readRequest(head[1]);
   endrule
   
   // methods (first < deq < enq < clear)
   method data_t first() if (notEmpty);
      return bram.readResponse();
   endmethod
      
   method Action deq() if (notEmpty);
      if (head[0] == hi_index)
	 begin
	    head[0] <= 0;
	    over[0] <= !over[0];
	 end
      else
	 begin
	    head[0] <= head[0] + 1;
	 end
   endmethod

   method Action enq(data_t data) if (notFull);
      if (tail == hi_index)
	 begin
	    tail <= 0;
	    over[1] <= !over[1]; 
	 end
      else
	 begin
	    tail <= tail + 1;
	 end
      bram.writeRequest(tail,data);
   endmethod
   
   method Action clear();
      tail <= head[1];
      over[2] <= False;
   endmethod
endmodule




