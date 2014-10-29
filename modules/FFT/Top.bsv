// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;
import MemPortal::*;

// generated by tool
import FFTInterface::*;
import FFTIndicationProxy::*;
import FFTRequestWrapper::*;

// defined by user
import FFTIFFTTest::*;

typedef enum {FFTIndication, FFTRequest} IfcNames deriving (Eq,Bits);

module mkConnectalTop(StdConnectalTop#(PhysAddrWidth));

   // instantiate user portals
   FFTIndicationProxy simpleIndicationProxy <- mkFFTIndicationProxy(FFTIndication);
   FFTRequest simpleRequest <- mkFFTRequest(simpleIndicationProxy.ifc);
   FFTRequestWrapper simpleRequestWrapper <- mkFFTRequestWrapper(FFTRequest,simpleRequest);
   
   Vector#(2,StdPortal) portals;
   portals[0] = simpleRequestWrapper.portalIfc;
   portals[1] = simpleIndicationProxy.portalIfc;
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;

endmodule : mkConnectalTop


