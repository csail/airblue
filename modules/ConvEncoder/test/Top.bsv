//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2014 Quanta Resarch Cambridge, Inc.
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

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


