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

// generated by tool
import FFTInterface::*;
import FFTIndicationProxy::*;
import FFTRequestWrapper::*;

// defined by user
import FFTIFFTTest::*;

module mkConnectalTop(StdConnectalTop#(PhysAddrWidth));

   // instantiate user portals
   FFTIndicationProxy fftIndicationProxy <- mkFFTIndicationProxy(FFTIndicationPortal);
   FFTRequest fftRequest <- mkFFTRequest(fftIndicationProxy.ifc);
   FFTRequestWrapper fftRequestWrapper <- mkFFTRequestWrapper(FFTRequestPortal,fftRequest);
   
   Vector#(2,StdPortal) portals;
   portals[0] = fftRequestWrapper.portalIfc;
   portals[1] = fftIndicationProxy.portalIfc;

   // instantiate system directory
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;

endmodule : mkConnectalTop


