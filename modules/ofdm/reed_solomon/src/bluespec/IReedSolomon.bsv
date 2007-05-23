import GetPut::*;
import Vector::*;
import ReedTypes::*;


interface Read#(type rv);
   method rv read();
endinterface


interface IReedSolomon;

   interface Put#(Byte) rs_t_in;
   interface Put#(Byte) rs_k_in;
   interface Put#(Byte) rs_input;
   interface Get#(Byte) rs_output;
   interface Get#(Bool) rs_flag;
      
endinterface

