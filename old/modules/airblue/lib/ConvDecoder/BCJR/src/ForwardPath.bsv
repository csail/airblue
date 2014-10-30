import Connectable::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import FShow::*;
import Probe::*;

// Local includes
import AirblueTypes::*;
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/reversal_buffer.bsh"


interface ForwardPath;
   interface Put#(PathMetricUnitIn) in;
   interface Get#(VPathMetricUnitOut) out;
endinterface


module mkForwardPath (ForwardPath);

   // Forward Path Blocks
   PathMetricUnit pmuForward <- mkPathMetricUnit(
      "BCJR PMU Forward",
      getPMUOutBCJRForward,
      getBranchMetricForward);

   interface in = pmuForward.in;
   interface out = pmuForward.out;

endmodule


module mkPathMetricEstimate(ForwardPath forwardPath,
                            Get#(Vector#(VTotalStates,VPathMetric)) ifc);
   method ActionValue#(Vector#(VTotalStates,VPathMetric)) get();
      return initPathMetricZero();
   endmethod
endmodule
