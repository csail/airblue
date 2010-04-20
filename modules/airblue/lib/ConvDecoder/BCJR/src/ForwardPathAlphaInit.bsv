import Connectable::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import FShow::*;
import Probe::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/reversal_buffer.bsh"


typedef Vector#(VTotalStates,VPathMetric) PathMetricVector;


interface ForwardPath;
   interface Put#(PathMetricUnitIn) in;
   interface Get#(VPathMetricUnitOut) out;
   interface Get#(PathMetricVector) pathMetric;
endinterface


module mkForwardPath (ForwardPath);

   // Forward Path Blocks
   PathMetricUnit pmuForward <- mkPathMetricUnit(
      "BCJR PMU Forward",
      getPMUOutBCJRForward,
      getBranchMetricForward);

   FIFOF#(VPathMetricUnitOut) pmuForwardOut <- mkSizedFIFOF(`REVERSAL_BUFFER_SIZE*4);
   FIFOF#(PathMetricVector) forwardPathMetric <- mkSizedFIFOF(4);
   Reg#(Bit#(`REVERSAL_BUFFER_SIZE)) forwardInitCounter <- mkReg(0);
   // Never send initialization for first block
   Reg#(Bool) firstBlockForward <- mkReg(True);

   // Send the pmuForward Estimates to the backward path
   rule feedEstimates;
     let pmuForwardResult <- pmuForward.out.get();
     pmuForwardOut.enq(pmuForwardResult);

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR Forward Path counter: %d", forwardInitCounter);
       end

     if(tpl_1(pmuForwardResult)) 
       begin
         if(`DEBUG_BCJR == 1)
           begin
             $display("BCJR Forward Path sends initialization to backward path (final bit)");
           end

         forwardPathMetric.enq(tpl_1(unzip(tpl_2(pmuForwardResult))));
         forwardInitCounter <= 0;
         firstBlockForward <= True;
       end
     else if(forwardInitCounter + 1 == `REVERSAL_BUFFER_SIZE)
       begin
         if(`DEBUG_BCJR == 1)
           begin
             $display("BCJR Forward Path sends initialization to backward path (block)");
           end

         forwardPathMetric.enq(tpl_1(unzip(tpl_2(pmuForwardResult))));
         firstBlockForward <= False;
         forwardInitCounter <= 0;
       end
     else
       begin
         forwardInitCounter <= forwardInitCounter + 1;
       end

     if(tpl_1(pmuForwardResult) && (`DEBUG_BCJR == 1)) 
       begin 
         $display("BCJR Forward Path reset");
       end
   endrule


   interface in = pmuForward.in;
   interface out = toGet(pmuForwardOut);
   interface pathMetric = toGet(forwardPathMetric);

endmodule


module mkPathMetricEstimate(ForwardPath forwardPath,
                            Get#(PathMetricVector) ifc);
   return forwardPath.pathMetric;
endmodule
