import BRAMFIFO::*;
import FIFO::*;

// (* synthesize *)
module mkBRAMFIFOTest (Empty);
   
   // constants
   Bit#(1) lo_index = 0;
   Bit#(1) hi_index = 1;
   
   // state elements
   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFO#(Bit#(32)) fifo <- mkBRAMFIFO(lo_index,hi_index);
   
   // rules
   rule enqFIFO (True);
      fifo.enq(cycle);
      $display("Enq data: %d at cycle %d", cycle, cycle);
   endrule
   
   rule readFIFO (True);
      $display("First data: %d at cycle %d", fifo.first, cycle);
   endrule
   
   rule deqFIFO (cycle[1:0] == 0);
      fifo.deq();
      $display("Deq data: %d at cycle %d", fifo.first, cycle);
   endrule
   
   rule tick (True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
   endrule   
endmodule