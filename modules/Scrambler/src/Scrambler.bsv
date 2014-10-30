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

// import DataTypes::*;
import Interfaces::*;
// import Controls::*;
// import LibraryFunctions::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;

function a choose(Bool b, a x, a y);
   return b ? x : y;
endfunction

module mkScrambler#(function ScramblerCtrl#(n,shifter_sz) 
		       mapCtrl(i_ctrl_t ctrl),
                    function o_ctrl_t convertCtrl(i_ctrl_t ctrl),
                    Bit#(shifter_sz) genPoly)
   (Scrambler#(i_ctrl_t,o_ctrl_t,n,n))
   provisos(Add#(1,xxA,shifter_sz),
	    Bits#(i_ctrl_t,i_ctrl_sz),
	    Bits#(o_ctrl_t,o_ctrl_sz));
   
   // state elements
   Reg#(Bit#(shifter_sz)) shiftReg <- mkReg(?);
   FIFO#(ScramblerMesg#(i_ctrl_t,n)) inQ <- mkLFIFO;
   FIFO#(EncoderMesg#(o_ctrl_t,n))  outQ <- mkSizedFIFO(2);

   // rule
   rule execScramble(True);
      let mesg = inQ.first;
      let ctrl = mesg.control;
      let data = mesg.data;
      Vector#(n,Bit#(1)) iDataVec = unpack(data);
      let sCtrl = mapCtrl(ctrl);
      let initTup = tuple2(0,fromMaybe(shiftReg,sCtrl.seed));
      let oCtrl = convertCtrl(ctrl);
      let oVec = sscanl(scramble(genPoly),initTup,iDataVec);
      match {.oDataVec,.seqVec} = unzip(oVec);
      Vector#(n,Bool) bypassVec = unpack(sCtrl.bypass);
      let oData = pack(map3(choose,bypassVec,iDataVec,oDataVec));
      inQ.deq;
      shiftReg <= seqVec[valueOf(n)-1]; // last seq is what we want
      outQ.enq(Mesg{control:oCtrl, data:oData});
   endrule
   
   //methods
   interface in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule










