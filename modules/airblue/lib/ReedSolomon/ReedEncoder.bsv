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

module mkReedEncoder#(function ReedSolomonCtrl#(8) mapCtrl(ctrl_t ctrl))
   (ReedEncoder#(ctrl_t,sz,sz))
   provisos(Mul#(num,8,sz),
	    Bits#(ctrl_t, ctrl_sz));

    Vector#(16, Bit#(8)) gPoly = newVector();

    gPoly[15] = 59;
    gPoly[14] = 13;
    gPoly[13] = 104;
    gPoly[12] = 189;
    gPoly[11] = 68;
    gPoly[10] = 209;
    gPoly[9]  = 30;
    gPoly[8]  = 8;
    gPoly[7]  = 163;
    gPoly[6]  = 65;
    gPoly[5]  = 41;
    gPoly[4]  = 229;
    gPoly[3]  = 98;
    gPoly[2]  = 50;
    gPoly[1]  = 36;
    gPoly[0]  = 59;

    FIFO#(EncoderMesg#(ctrl_t, sz))  inQ <- mkLFIFO;
    FIFO#(EncoderMesg#(ctrl_t, sz)) outQ <- mkSizedFIFO(2);
    Reg#(ctrl_t)                 control <- mkRegU;

    Reg#(Bit#(8))  inCounter <- mkReg(0);
    Reg#(Bit#(8)) outCounter <- mkReg(0);
    Reg#(Vector#(16, Bit#(8))) shiftRegs <- mkReg(replicate(0));

    function Bit#(8) mul(Bit#(8) a, Bit#(8) b);
        Bit#(8) z = 0;
        z[0] = b[0]&a[0]^b[1]&a[7]^b[2]&a[6]^b[3]&a[5]^b[4]&a[4]^b[5]&a[3]^b[5]&a[7]^b[6]&a[2]^b[6]&a[6]^b[6]&a[7]^b[7]&a[1]^b[7]&a[5]^b[7]&a[6]^b[7]&a[7];
        z[1] = b[0]&a[1]^b[1]&a[0]^b[2]&a[7]^b[3]&a[6]^b[4]&a[5]^b[5]&a[4]^b[6]&a[3]^b[6]&a[7]^b[7]&a[2]^b[7]&a[6]^b[7]&a[7];
        z[2] = b[0]&a[2]^b[1]&a[1]^b[1]&a[7]^b[2]&a[0]^b[2]&a[6]^b[3]&a[5]^b[3]&a[7]^b[4]&a[4]^b[4]&a[6]^b[5]&a[3]^b[5]&a[5]^b[5]&a[7]^b[6]&a[2]^b[6]&a[4]^b[6]&a[6]^b[6]&a[7]^b[7]&a[1]^b[7]&a[3]^b[7]&a[5]^b[7]&a[6];
        z[3] = b[0]&a[3]^b[1]&a[2]^b[1]&a[7]^b[2]&a[1]^b[2]&a[6]^b[2]&a[7]^b[3]&a[0]^b[3]&a[5]^b[3]&a[6]^b[4]&a[4]^b[4]&a[5]^b[4]&a[7]^b[5]&a[3]^b[5]&a[4]^b[5]&a[6]^b[5]&a[7]^b[6]&a[2]^b[6]&a[3]^b[6]&a[5]^b[6]&a[6]^b[7]&a[1]^b[7]&a[2]^b[7]&a[4]^b[7]&a[5];
        z[4] = b[0]&a[4]^b[1]&a[3]^b[1]&a[7]^b[2]&a[2]^b[2]&a[6]^b[2]&a[7]^b[3]&a[1]^b[3]&a[5]^b[3]&a[6]^b[3]&a[7]^b[4]&a[0]^b[4]&a[4]^b[4]&a[5]^b[4]&a[6]^b[5]&a[3]^b[5]&a[4]^b[5]&a[5]^b[6]&a[2]^b[6]&a[3]^b[6]&a[4]^b[7]&a[1]^b[7]&a[2]^b[7]&a[3]^b[7]&a[7];
        z[5] = b[0]&a[5]^b[1]&a[4]^b[2]&a[3]^b[2]&a[7]^b[3]&a[2]^b[3]&a[6]^b[3]&a[7]^b[4]&a[1]^b[4]&a[5]^b[4]&a[6]^b[4]&a[7]^b[5]&a[0]^b[5]&a[4]^b[5]&a[5]^b[5]&a[6]^b[6]&a[3]^b[6]&a[4]^b[6]&a[5]^b[7]&a[2]^b[7]&a[3]^b[7]&a[4];
        z[6] = b[0]&a[6]^b[1]&a[5]^b[2]&a[4]^b[3]&a[3]^b[3]&a[7]^b[4]&a[2]^b[4]&a[6]^b[4]&a[7]^b[5]&a[1]^b[5]&a[5]^b[5]&a[6]^b[5]&a[7]^b[6]&a[0]^b[6]&a[4]^b[6]&a[5]^b[6]&a[6]^b[7]&a[3]^b[7]&a[4]^b[7]&a[5];
        z[7] = b[0]&a[7]^b[1]&a[6]^b[2]&a[5]^b[3]&a[4]^b[4]&a[3]^b[4]&a[7]^b[5]&a[2]^b[5]&a[6]^b[5]&a[7]^b[6]&a[1]^b[6]&a[5]^b[6]&a[6]^b[6]&a[7]^b[7]&a[0]^b[7]&a[4]^b[7]&a[5]^b[7]&a[6];
        return z;
    endfunction

    rule outTime (outCounter != 0);
       Vector#(num, Bit#(8)) vecMesg = replicate(0);
       for(Integer i = 0; i < valueOf(num); i=i+1)
	  begin
	     Bit#(4) outIdx = truncate(16-outCounter+fromInteger(i));
             vecMesg[i] = (shiftRegs._read())[outIdx];
	  end
       outQ.enq(Mesg{control: control, data: pack(vecMesg)});
       let newOutCounter = outCounter - fromInteger(valueOf(num));
       outCounter <= newOutCounter;
       if(newOutCounter == 0)
          shiftRegs <= replicate(0);
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
            Vector#(16, Bit#(8)) newShiftRegs  = shiftRegs;
            Vector#(num, Bit#(8)) vecMesg = unpack(mesg.data);
            for(Integer b = valueOf(num) - 1; b >= 0; b=b-1)
            begin
                let dataIn   = vecMesg[b];
                let feedback = newShiftRegs[15]^dataIn;
                Vector#(16, Bit#(8)) muls = newVector();
                for(Integer j = 0; j < 16; j=j+1)
                    muls[j] = mul(feedback, gPoly[j]);
                Vector#(16, Bit#(8)) vals = newVector();
                for(Integer j = 1; j < 16; j=j+1)
                    vals[j] = muls[j] ^ newShiftRegs[j-1];
                vals[0] = muls[0];
                newShiftRegs = vals;
            end
            shiftRegs <= newShiftRegs;
            inCounter  <= newInCounter;
            outCounter <= newOutCounter;
            outQ.enq(mesg);
        end
    endrule

    interface in  = fifoToPut(inQ);
    interface out = fifoToGet(outQ);
endmodule



