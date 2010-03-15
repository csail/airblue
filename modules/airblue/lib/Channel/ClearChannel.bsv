import FIFO::*;
import GetPut::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

(* synthesize *)
module mkChannel(Channel#(2,14));

   // states
   FIFO#(FPComplex#(2,14)) queue <- mkFIFO;
   
   interface in = toPut(queue);
   interface out = toGet(queue);

endmodule
