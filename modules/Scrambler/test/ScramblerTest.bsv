//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
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

import FIFO::*;
import GetPut::*;
import Vector::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
import Scrambler::*;
import Descrambler::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
import Scrambler::*;

function t idFunc(t in);
   return in;
endfunction

typedef enum {
   ScramblerRequestPortal,
   ScramblerIndicationPortal
   } IfcNames deriving (Bits);

interface ScramblerRequest;
   method Action putInput(Bit#(12) data);
endinterface

interface ScramblerIndication;
   method Action putOutput(Bit#(20) inputControl, Bit#(12) inputData, Bit#(20) scramblerControl, Bit#(12) scramblerData, Bit#(20) descramblerControl, Bit#(12) descramblerData);
endinterface

module mkScramblerTest#(ScramblerIndication indication)(ScramblerRequest);
   
   // state elements
   Scrambler#(ScramblerCtrl#(12,7),ScramblerCtrl#(12,7),12,12) scrambler <- mkScrambler(idFunc,idFunc,7'b1001000);
   Descrambler#(ScramblerCtrl#(12,7),12,12) descrambler <- mkDescrambler(idFunc,7'b1001000);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   FIFO#(ScramblerMesg#(ScramblerCtrl#(12,7),12)) dataFifo <- mkFIFO();
   FIFO#(EncoderMesg#(ScramblerCtrl#(12,7),12)) scrambledFifo <- mkFIFO();
   
   rule scramblerOutput;
      let mesg <- scrambler.out.get;
      //$display("  scrambler output: data: %b",mesg.data);
      descrambler.in.put(mesg);
      scrambledFifo.enq(mesg);
   endrule
   
   rule descramblerOutput;
      let mesg <- descrambler.out.get;
      //$display("descrambler output: data: %b",mesg.data);
      let dataMesg <- toGet(dataFifo).get();
      let scrambledMesg <- toGet(scrambledFifo).get();
      indication.putOutput(pack(dataMesg.control),
			   pack(dataMesg.data),
			   pack(scrambledMesg.control),
			   pack(scrambledMesg.data),
			   pack(mesg.control),
			   pack(mesg.data));
   endrule

   rule tick(True);
      cycle <= cycle + 1;
   endrule
  
   method Action putInput(Bit#(12) data);
      let mesg = Mesg { control: ScramblerCtrl
		       {bypass: 0,
			seed: (data[4:0] == 0) ? tagged Valid 127 : Invalid},
	   	        data: data};
      scrambler.in.put(mesg);
      dataFifo.enq(mesg);
      //$display("  scrambler input: data: %b",data);
   endmethod

endmodule




