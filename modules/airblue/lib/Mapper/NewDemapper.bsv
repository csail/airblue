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

import Complex::*;
import Controls::*;
import DataTypes::*;
import FIFO::*;
import FixedPoint::*;
import FPComplex::*;
import Interfaces::*;
import Vector::*;
import GetPut::*;
import VectorLibrary::*;
import StreamFIFO::*;

// assume no overflow
function FixedPoint#(ai,af) demapMult(Integer m, FixedPoint#(ai,af) fp)
   provisos (Arith#(FixedPoint#(ai,af)));   
   FixedPoint#(ai,af) res = 0;
   for(Integer i = 0; i < m; i = i + 1)
      res = res + fp;
   return res;
endfunction

// aux functions
function ViterbiMetric decodeRange(FixedPoint#(ai,af) in, FixedPoint#(ai,af) start, FixedPoint#(ai,af) incr, Bool startZero)
  provisos (Add#(1,xxA,ai), Literal#(FixedPoint#(ai,af)),
	    Arith#(FixedPoint#(ai,af)));
      let result = (in < start + incr) ?
		   (startZero ? 0 : 7) :
		   (in < start + demapMult(2,incr)) ?
		   (startZero ? 1 : 6) :
		   (in < start + demapMult(3,incr)) ?
		   (startZero ? 2 : 5) :
		   (in < start + demapMult(4,incr)) ?
		   (startZero ? 3 : 4) :
		   (in < start + demapMult(5,incr)) ?
		   (startZero ? 4 : 3) :
		   (in < start + demapMult(6,incr)) ?
		   (startZero ? 5 : 2) :
		   (in < start + demapMult(7,incr)) ?
		   (startZero ? 6 : 1) :
		   (startZero ? 7 : 0);
      return result;
endfunction // ViterbiMetric

function ViterbiMetric decodeBPSK(Bool negateOutput,
				  FPComplex#(ai,af) in)
  provisos (Add#(1,xxA,ai), Literal#(FixedPoint#(ai,af)),
	    Arith#(FixedPoint#(ai,af)));
      return decodeRange(in.rel, -1, fromRational(1,4), !negateOutput);
endfunction // ConfLvl

function Vector#(2, ViterbiMetric) decodeQPSK(Bool negateOutput,
					      FPComplex#(ai,af) in)
  provisos (Add#(1,xxA,ai), Literal#(FixedPoint#(ai,af)),
	    Arith#(FixedPoint#(ai,af)));

      function ViterbiMetric decodeQPSKAux(FixedPoint#(ai,af) fp);
         return decodeRange(fp, fromRational(-707106781,1000000000), fromRational(17676695,1000000000), !negateOutput);
      endfunction

      Vector#(2, ViterbiMetric) result = newVector;
      result[0] = decodeQPSKAux(in.rel);
      result[1] = decodeQPSKAux(in.img);
      return result;
endfunction // ConfLvl      


function Vector#(4, ViterbiMetric) decodeQAM_16(Bool negateOutput,
						FPComplex#(ai,af) in)
  provisos (Add#(1,xxA,ai), Literal#(FixedPoint#(ai,af)),
	    Arith#(FixedPoint#(ai,af)));

      // aux funcs
      function ViterbiMetric decodeQAM_16_Even(FixedPoint#(ai,af) x);
	 return decodeRange(x, fromRational(-316227766,1000000000), fromRational(79056942,1000000000), !negateOutput);
      endfunction // ConfLvl      
      
      function ViterbiMetric decodeQAM_16_Odd(FixedPoint#(ai,af) x);
         let result = (x < 0) ?
		      decodeRange(x, fromRational(-948683298,1000000000), fromRational(79056942,1000000000),!negateOutput) :
		      decodeRange(x, fromRational(316227766,1000000000), fromRational(79056942,1000000000),negateOutput);      
	 return result;
      endfunction // ConfLvl      

      Vector#(4, ViterbiMetric) result = newVector;
      result[0] = decodeQAM_16_Even(in.rel);
      result[1] = decodeQAM_16_Odd(in.rel);
      result[2] = decodeQAM_16_Even(in.img);
      result[3] = decodeQAM_16_Odd(in.img);
      return result;
endfunction

function Vector#(6, ViterbiMetric) decodeQAM_64(Bool negateOutput,
						FPComplex#(ai,af) in)
  provisos (Add#(1,xxA,ai), Literal#(FixedPoint#(ai,af)),
	    Arith#(FixedPoint#(ai,af)));

      // aux funcs
      function ViterbiMetric decodeQAM_64_0(FixedPoint#(ai,af) x);
	 return decodeRange(x, fromRational(-154303350,1000000000), fromRational(38575837,1000000000), !negateOutput);
      endfunction // ConfLvl      
      
      function ViterbiMetric decodeQAM_64_1(FixedPoint#(ai,af) x);
         let result = (x < 0) ?
		      decodeRange(x, fromRational(-771516750,1000000000), fromRational(38575837,1000000000),!negateOutput) :
		      decodeRange(x, fromRational(462910050,1000000000), fromRational(38575837,1000000000),negateOutput);      
	 return result;
      endfunction
      
      function ViterbiMetric decodeQAM_64_2(FixedPoint#(ai,af) x);
	 let result = (x < fromRational(-617213400,1000000000)) ?
		      decodeRange(x, fromRational(-1080123450,1000000000), fromRational(38575837,1000000000),!negateOutput) :	
		      (x < 0) ? 
		      decodeRange(x, fromRational(-462910050,1000000000), fromRational(38575837,1000000000),negateOutput) :	
		      (x < fromRational(617213400,1000000000)) ?
		      decodeRange(x, fromRational(154303350,1000000000), fromRational(38575837,1000000000),!negateOutput) :	
		      decodeRange(x, fromRational(771516750,1000000000), fromRational(38575837,1000000000),negateOutput);	
	 return result;
      endfunction // ConfLvl      

      Vector#(6, ViterbiMetric) result = newVector;
      result[0] = decodeQAM_64_0(in.rel);
      result[1] = decodeQAM_64_1(in.rel);
      result[2] = decodeQAM_64_2(in.rel);
      result[3] = decodeQAM_64_0(in.img);
      result[4] = decodeQAM_64_1(in.img);
      result[5] = decodeQAM_64_2(in.img);
      return result;
endfunction 

// mkMapper definition, 
// i_n must equal no of data carriers, dividable by o_n
// o_n must be multiple of 12
// negateOutput: False: mapper maps 0 to -1 and 1 to 1
//               TrueL mapper maps 1 to -1 and 0 to 1
module mkDemapper#(function Modulation mapCtrl(ctrl_t inCtrl),
		   Bool negateOutput) 
   (Demapper#(ctrl_t,i_n,o_n,i_prec,f_prec,ViterbiMetric))
   provisos(Bits#(ctrl_t,ctrl_sz),
	    Add#(1,xxA,i_prec), 
	    Literal#(FixedPoint#(i_prec,f_prec)), 
	    Arith#(FixedPoint#(i_prec,f_prec)),
	    Mul#(2,qpsk_n,o_n), 
	    Mul#(4,qam16_n,o_n), 
            Mul#(6,qam64_n,o_n),
            Add#(1,xxB,o_n),
	    Add#(2,xxC,o_n), 
	    Add#(4,xxD,o_n), 
	    Add#(6,xxE,o_n),
            Add#(i_n,1,i_n_p_1),
            Log#(i_n_p_1,i_s_sz),
            Add#(o_n,1,o_n_p_1),
            Log#(o_n_p_1,o_s_sz));
   
   // constants
   Bit#(i_s_sz) inSz  = fromInteger(valueOf(i_n));
   Bit#(o_s_sz) outSz = fromInteger(valueOf(o_n));
		      
   // state elements
   Reg#(ctrl_t)       lastCtrl <- mkRegU;
   Reg#(Bit#(i_s_sz)) counter  <- mkReg(inSz);
   Reg#(Modulation)   modulation <- mkRegU;
   FIFO#(DemapperMesg#(ctrl_t,i_n,i_prec,f_prec)) inQ <- mkLFIFO;
   StreamFIFO#(o_n,o_s_sz,ViterbiMetric) outQ;
   outQ <- mkStreamFIFO;

//DeinterleaverMesg#(ctrl_t,o_n,ViterbiMetric)) outQ <- mkSizedFIFO(1);
      
   let inMesg = inQ.first();
   let inCtrl = inMesg.control;
   let inData = inMesg.data;
                
   // rules
   rule processNextInMesg(counter==inSz && !outQ.notEmpty(1));
      lastCtrl   <= inCtrl;
      modulation <= mapCtrl(inCtrl);
      counter <= 0;
   endrule
   
   rule demapBPSK(counter < inSz 
                  && modulation == BPSK
                  && outQ.notFull(1));
      Vector#(1,ViterbiMetric) decodedData = replicate(decodeBPSK(negateOutput,inData[counter]));
      counter <= counter + 1;
      outQ.enq(1,append(decodedData,?));
      if (counter == inSz-1)
         inQ.deq();
   endrule

   rule demapQPSK(counter < inSz 
                  && modulation == QPSK
                  && outQ.notFull(2));
      Vector#(2,ViterbiMetric) decodedData = decodeQPSK(negateOutput,inData[counter]);
      counter <= counter + 1;
      outQ.enq(2,append(decodedData,?));
      if (counter == inSz-1)
         inQ.deq();
   endrule

   rule demapQAM_16(counter < inSz 
                    && modulation == QAM_16
                    && outQ.notFull(4));
      Vector#(4,ViterbiMetric) decodedData = decodeQAM_16(negateOutput,inData[counter]);
      counter <= counter + 1;
      outQ.enq(4,append(decodedData,?));
      if (counter == inSz-1)
         inQ.deq();
   endrule

   rule demapQAM_64(counter < inSz 
                    && modulation == QAM_64
                    && outQ.notFull(6));
      Vector#(6,ViterbiMetric) decodedData = decodeQAM_64(negateOutput,inData[counter]);
      counter <= counter + 1;
      outQ.enq(6,append(decodedData,?));
      if (counter == inSz-1)
         inQ.deq();
   endrule
                      
   // methods
   interface  in = fifoToPut(inQ);
   interface Get out;
      method ActionValue#(DeinterleaverMesg#(ctrl_t,o_n,ViterbiMetric)) get()
         if (outQ.notEmpty(outSz));
         outQ.deq(outSz);
         return Mesg{control: lastCtrl, data: outQ.first()};
      endmethod
   endinterface
endmodule // mkDemapper      






