import FIFO::*;
import GetPut::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

interface Channel#(type ai, type af);
   interface Put#(FPComplex#(ai, af)) in;
   interface Get#(FPComplex#(ai, af)) out;
endinterface


(* synthesize *)
module mkChannel(Channel#(2,14));

   // states
   FIFO#(FPComplex#(2,14)) queue <- mkFIFO;
   
   interface in = toPut(queue);
   interface out = toGet(queue);

endmodule
