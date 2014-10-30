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
   method Action scramblerInput(Bit#(12) data);
endinterface

interface ScramblerIndication;
   method Action scramblerOutput(Bit#(20) control, Bit#(12) data);
   method Action descramblerOutput(Bit#(20) control, Bit#(12) data);
endinterface

module mkScramblerTest#(ScramblerIndication indication)(ScramblerRequest);
   
   // state elements
   Scrambler#(ScramblerCtrl#(12,7),ScramblerCtrl#(12,7),12,12) scrambler <- mkScrambler(idFunc,idFunc,7'b1001000);
   Descrambler#(ScramblerCtrl#(12,7),12,12) descrambler <- mkDescrambler(idFunc,7'b1001000);
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule scramblerOutput;
      let mesg <- scrambler.out.get;
      $display("  scrambler output: data: %b",mesg.data);
      indication.scramblerOutput(pack(mesg.control),
				 pack(mesg.data));
      descrambler.in.put(mesg);
   endrule
   
   rule descramblerOutput;
      let mesg <- descrambler.out.get;
      $display("descrambler output: data: %b",mesg.data);
      indication.descramblerOutput(pack(mesg.control),
				   pack(mesg.data));
   endrule

   rule tick(True);
      cycle <= cycle + 1;
   endrule
  
   method Action scramblerInput(Bit#(12) data);
      let mesg = Mesg { control: ScramblerCtrl
		       {bypass: 0,
			seed: (data[4:0] == 0) ? tagged Valid 127 : Invalid},
	   	        data: data};
      scrambler.in.put(mesg);
      $display("  scrambler input: data: %b",data);
   endmethod

endmodule




