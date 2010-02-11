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

import Controls::*;
import DataTypes::*;
import FIFO::*;
import GetPut::*;
import Interfaces::*;
import BitStreamFIFO::*;
import Vector::*;

// for generating parallel functions
function Vector#(f_sz, Bit#(o_sz)) 
   parFunc(Bit#(f_sz) dummyVal,
	   function Bit#(o_sz) func(Bit#(i_sz) x),
	   Vector#(f_sz, Bit#(i_sz)) xs);
   return map(func, xs);
endfunction
   
// mkPuncturer using streamFIFO
// in_buf_sz > in_sz + Max(in_sz mod {f1/f2/f3}_in_sz)
// out_buf_sz > Max({f1/f2/f3}_out_sz + ({f1/f2/f3}_out_sz mod out_sz)) 
module mkPuncturer#(function Bit#(ctrl_bsz) 
                       puncturerCtrl(ctrl_t rate),
                    Vector#(ctrl_no, 
                            Tuple3#(Bit#(in_bsz),Bit#(out_bsz),
                                    function Bit#(in_sz) 
                                       puncFunc(Bit#(out_sz) x))))
   (Puncturer#(ctrl_t, in_sz, out_sz, in_buf_sz, out_buf_sz))
   provisos (// provisos inherit from BitStreamFIFO for in_buf_sz and in_sz
             Add#(in_buf_sz,1,in_buf_szp1),
             Log#(in_buf_szp1,in_buf_bsz),    
             Add#(in_sz,1,in_szp1),
             Log#(in_szp1,in_bsz), 
             Add#(xxA,in_bsz,in_buf_bsz),
             Add#(in_sz,xxB,in_buf_sz),
      
             // provisos inherit from BitStreamFIFO for in_buf_sz and in_sz
             Add#(out_buf_sz,1,out_buf_szp1),
             Log#(out_buf_szp1,out_buf_bsz),
             Add#(out_sz,1,out_szp1),
             Log#(out_szp1,out_bsz), 
	     Add#(xxC,out_bsz,out_buf_bsz),
             Add#(out_sz,xxD,out_buf_sz),

             // additional provisos
             Log#(ctrl_no,ctrl_bsz), // Bit#(ctrl_bsz) to represent ctrl_no of values
	     Bits#(ctrl_t,ctrl_sz),  // ctrl_t is bitable
	     Eq#(ctrl_t));           // ctrl_t can be compared
		       
   // constants
   Bit#(in_bsz)   inSz = fromInteger(valueOf(in_sz));
   Bit#(out_bsz) outSz = fromInteger(valueOf(out_sz));
		       
   // state elements
   Reg#(ctrl_t) lastCtrl <- mkRegU;
   FIFO#(EncoderMesg#(ctrl_t, in_sz)) inQ <- mkLFIFO;
   FIFO#(EncoderMesg#(ctrl_t, out_sz)) outQ <- mkSizedFIFO(2);
   BitStreamFIFO#(in_buf_sz,in_buf_bsz,in_sz,in_bsz,1) inStreamQ;
   let inStreamQ <- mkUGBitStreamLFIFO;
   BitStreamFIFO#(out_buf_sz,out_buf_bsz,out_sz,out_bsz,1) outStreamQ;
   let outStreamQ <- mkUGBitStreamLFIFO;
      
   let inMsg = inQ.first;
   let inCtrl = inMsg.control;
   let inData = inMsg.data;
   let inPCtrl = puncturerCtrl(inCtrl);   
   let lastPCtrl = puncturerCtrl(lastCtrl);
   match {.fInSz, .fOutSz} = case (lastPCtrl)
				Half: tuple2(f0InSz, f0OutSz);
				TwoThird: tuple2(f1InSz,f1OutSz);
				ThreeFourth: tuple2(f2InSz,f2OutSz);
				FiveSixth: tuple2(f3InSz,f3OutSz);
			     endcase; 
   let canEnqInStreamQ = zeroExtend(inSz) <= inStreamQ.free; inStreamQ.notFull(inSz);
   let canDeqInStreamQ = inStreamQ.notEmpty(fInSz);
   let canEnqOutStreamQ = outStreamQ.notFull(fOutSz);
   let canDeqOutStreamQ = outStreamQ.notEmpty(outSz); 
   
   rule enqInStreamQ(canEnqInStreamQ && (lastCtrl == inCtrl || (!canDeqInStreamQ && !canDeqOutStreamQ)));
      if (lastCtrl != inCtrl)
	 lastCtrl <= inCtrl;
      inQ.deq;
      inStreamQ.enq(inSz,unpack(zeroExtend(inData)));
   endrule
	
   rule puncture(canDeqInStreamQ && canEnqOutStreamQ);
      let data = inStreamQ.first;
      case (lastPCtrl)
	 Half:
	 begin
	    Bit#(in_sz) f0InData = truncate(pack(data));
	    Vector#(out_buf_sz,Bit#(1)) f0OutData = unpack(zeroExtend(f0InData));
	    inStreamQ.deq(f0InSz);
	    outStreamQ.enq(f0OutSz,f0OutData);
	 end
	 TwoThird:
	 begin
	    Vector#(f1_sz,Bit#(4)) f1InData = unpack(truncate(pack(data)));
	    Vector#(out_buf_sz,Bit#(1)) f1OutData = unpack(zeroExtend(pack(twoThird(f1InData))));
	    inStreamQ.deq(f1InSz);
	    outStreamQ.enq(f1OutSz,f1OutData);
	 end
	 ThreeFourth:
	 begin
	    Vector#(f2_sz,Bit#(6)) f2InData = unpack(truncate(pack(data)));
	    Vector#(out_buf_sz,Bit#(1)) f2OutData = unpack(zeroExtend(pack(threeFourth(f2InData))));
	    inStreamQ.deq(f2InSz);
	    outStreamQ.enq(f2OutSz,f2OutData);
	 end
	 FiveSixth:
	 begin
	    Vector#(f3_sz,Bit#(10)) f3InData = unpack(truncate(pack(data)));
	    Vector#(out_buf_sz,Bit#(1)) f3OutData = unpack(zeroExtend(pack(fiveSixth(f3InData))));
	    inStreamQ.deq(f3InSz);
	    outStreamQ.enq(f3OutSz,f3OutData);
	 end
      endcase
   endrule
		       
   rule deqOutStreamQ(canDeqOutStreamQ);
      Bit#(out_sz) outData = truncate(pack(outStreamQ.first));
      let outMsg = Mesg { control: lastCtrl,
			  data: outData};
      outStreamQ.deq(outSz);
      outQ.enq(outMsg);
   endrule
   
   interface Put in = fifoToPut(inQ);
   interface Get out = fifoToGet(outQ);
   
endmodule   
   
   




