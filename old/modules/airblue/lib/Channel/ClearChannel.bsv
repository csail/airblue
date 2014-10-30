import FIFO::*;
import GetPut::*;

// local includes
import AirblueCommon::*;
import AirblueTypes::*;

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
