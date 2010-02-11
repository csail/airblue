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

import DataTypes::*;
import Interfaces::*;
import Controls::*;
import FIFO::*;
import Vector::*;
import GetPut::*;

module mkReedDecoder#(function ReedSolomonCtrl#(8) mapCtrl(ctrl_t ctrl))
   (ReedDecoder#(ctrl_t,sz,sz))
    provisos(Mul#(num,8,sz),
             Bits#(ctrl_t, ctrl_sz));

    FIFO#(DecoderMesg#(ctrl_t,sz,Bit#(1)))  inQ <- mkLFIFO;
    FIFO#(DecoderMesg#(ctrl_t,sz,Bit#(1))) outQ <- mkSizedFIFO(2);
    Reg#(ctrl_t)                        control <- mkRegU;

    Reg#(Bit#(8))  inCounter <- mkReg(0);
    Reg#(Bit#(8)) outCounter <- mkReg(0);

    rule outTime (outCounter != 0);
        inQ.deq();
        let newOutCounter = outCounter - fromInteger(valueOf(num));
        outCounter <= newOutCounter;
    endrule

    rule normal (outCounter == 0);
        let mesg = inQ.first();
        inQ.deq();
        control <= mesg.control;
        let ctrl = mapCtrl(mesg.control);
        if(ctrl.in == 12)
            outQ.enq(mesg);
        else
        begin
            let newInCounter  = inCounter == 0 ? ctrl.in - fromInteger(valueOf(num)) : inCounter - fromInteger(valueOf(num));
            let newOutCounter = newInCounter == 0 ? ctrl.out : 0;
            inCounter  <= newInCounter;
            outCounter <= newOutCounter;
            outQ.enq(mesg);
        end
    endrule

    interface in  = fifoToPut(inQ);
    interface out = fifoToGet(outQ);
endmodule
