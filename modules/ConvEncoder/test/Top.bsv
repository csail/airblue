// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;
import MemPortal::*;

// defined by user
import ConvEncoderTest::*;

// generated by tool
import ConvEncoderIndicationProxy::*;
import ConvEncoderRequestWrapper::*;

module mkConnectalTop(StdConnectalTop#(PhysAddrWidth));

   // instantiate user portals
   ConvEncoderIndicationProxy convEncoderIndicationProxy <- mkConvEncoderIndicationProxy(ConvEncoderIndicationPortal);
   ConvEncoderRequest convEncoderTest <- mkConvEncoderTest(convEncoderIndicationProxy.ifc);
   ConvEncoderRequestWrapper convEncoderRequestWrapper <- mkConvEncoderRequestWrapper(ConvEncoderRequestPortal,convEncoderTest);
   
   Vector#(2,StdPortal) portals;
   portals[0] = convEncoderRequestWrapper.portalIfc;
   portals[1] = convEncoderIndicationProxy.portalIfc;

   // instantiate system directory
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;

endmodule : mkConnectalTop


