import RegFile::*;

// FPGA BRAM interface 
interface BRAM#(type index_t, type data_t);
   method Action readRequest(index_t index);
   method Action writeRequest(index_t index, data_t data);
   method data_t readResponse();
endinterface

// make BRAM with regfile (for simulation)
module mkRegFileBRAM#(index_t lo_index, index_t hi_index)  
   (BRAM#(index_t,data_t))
   provisos (Bits#(index_t,size_index),
	     Bits#(data_t,data_sz));
   
   // state elements
   RegFile#(index_t,data_t) mem <- mkRegFile(lo_index,hi_index);
   Reg#(index_t) readIdx <- mkRegU;
   
   // methods
   method Action readRequest(index_t index);
      readIdx <= index;
   endmethod
   
   method Action writeRequest(index_t index, data_t data);
      mem.upd(index,data);
   endmethod
   
   method data_t readResponse();
      return mem.sub(readIdx);
   endmethod
endmodule

   
