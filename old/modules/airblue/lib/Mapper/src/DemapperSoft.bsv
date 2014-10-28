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

// implement the demapper based on the publication 
// "Simplified Soft-Output Demapper for Binary Interleaved COFDM with Application to HIPERLAN/2"
// by Fillippo Tosato and Paola Bisaglia   

import Complex::*;
import FIFO::*;
import FixedPoint::*;
import GetPut::*;
import Vector::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
// import VectorLibrary::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

// check the input values and convert them to range=[-1,1)
function FixedPoint#(1,af) convertRange(FixedPoint#(ai,af) fp)
   provisos (Add#(xxA, 1, ai)); 
   if (fp >= 1 || fp < -1)
      if (fp < -1)
         return minBound;
      else
         return maxBound; 
   else
      return fxptTruncate(fp); 
endfunction

function Bit#(a) demap0(FixedPoint#(1,af) fp)
   provisos (Add#(a,xxA,SizeOf#(FixedPoint#(1,af))));
   
   return tpl_1(split(pack(fp))); 
endfunction

// half = half the distance
function Bit#(a) demap1(FixedPoint#(1,af) fp, FixedPoint#(1,af) half)
   provisos (Add#(a,xxA,SizeOf#(FixedPoint#(1,af))));
   
   if (fp > 0)
      return tpl_1(split(pack(negate(fp) + half)));
   else
      return tpl_1(split(pack(fp + half)));   
endfunction

// quarter = quarter of the distance
function Bit#(a) demap2(FixedPoint#(1,af) fp, FixedPoint#(1,af) quarter)
   provisos (Add#(a,xxA,SizeOf#(FixedPoint#(1,af))));
   
   if (fp > 0)
      if (fp > 0.5)
         return tpl_1(split(pack(negate(fp)+quarter+quarter+quarter)));
      else
         return tpl_1(split(pack(fp-quarter)));
   else
      if (fp < -0.5)
         return tpl_1(split(pack(fp+quarter+quarter+quarter)));
      else
         return tpl_1(split(pack(negate(fp)-quarter)));

endfunction   

function Bit#(a) decodeBPSK(Bool negateOutput,
				  FPComplex#(ai,af) in)
  provisos (Add#(xxA, 1, ai),
            Add#(a,xxB,SizeOf#(FixedPoint#(1,af))));

   return demap0(convertRange((!negateOutput ? negate(in.rel) : in.rel)));
endfunction // ConfLvl

function Vector#(2, Bit#(a)) decodeQPSK(Bool negateOutput,
					      FPComplex#(ai,af) in)
  provisos (Add#(xxA, 1, ai),
            Add#(a,xxB,SizeOf#(FixedPoint#(1,af))));

   Vector#(2, Bit#(a)) result = newVector;
   result[0] = demap0(convertRange((!negateOutput ? negate(in.rel) : in.rel)));
   result[1] = demap0(convertRange((!negateOutput ? negate(in.img) : in.img)));
   return result;
endfunction // ConfLvl      


function Vector#(4, Bit#(a)) decodeQAM_16(Bool negateOutput,
						FPComplex#(ai,af) in)
  provisos (Add#(xxA, 1, ai),
            Add#(a,xxB,SizeOf#(FixedPoint#(1,af))));

   Vector#(4, Bit#(a)) result = newVector;
   result[0] = demap0(convertRange((!negateOutput ? negate(in.rel) : in.rel)));
   result[1] = demap1(convertRange((!negateOutput ? negate(in.rel) : in.rel)),0.632455532034); // 4/sqrt(10)/2
   result[2] = demap0(convertRange((!negateOutput ? negate(in.img) : in.img)));
   result[3] = demap1(convertRange((!negateOutput ? negate(in.img) : in.img)),0.632455532034);
   return result;
endfunction

function Vector#(6, Bit#(a)) decodeQAM_64(Bool negateOutput,
						FPComplex#(ai,af) in)
  provisos (Add#(xxA, 1, ai),
            Add#(a,xxB,SizeOf#(FixedPoint#(1,af))));

   Vector#(6, Bit#(a)) result = newVector;
   result[0] = demap0(convertRange((!negateOutput ? negate(in.rel) : in.rel)));
   result[1] = demap1(convertRange((!negateOutput ? negate(in.rel) : in.rel)),0.617213399848); // 8/sqrt(42)/2
   result[2] = demap2(convertRange((!negateOutput ? negate(in.rel) : in.rel)),0.308606699924);// 8/sqrt(42)/4
   result[3] = demap0(convertRange((!negateOutput ? negate(in.img) : in.img)));
   result[4] = demap1(convertRange((!negateOutput ? negate(in.img) : in.img)),0.617213399848);
   result[5] = demap2(convertRange((!negateOutput ? negate(in.img) : in.img)),0.308606699924);
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
	    Add#(xxA,1,i_prec), 
	    Mul#(2,qpsk_n,o_n), 
	    Mul#(4,qam16_n,o_n), 
	    Mul#(6,qam64_n,o_n),
	    Mul#(xxB,o_n,i_n),
	    Mul#(xxC,qpsk_n,i_n),
	    Mul#(xxD,qam16_n,i_n),
	    Mul#(xxE,qam64_n,i_n),
            Log#(i_n,idx_sz),
            Add#(4,xxF,TAdd#(32,f_prec)),
            Add#(SizeOf#(ViterbiMetric),xxG,SizeOf#(FixedPoint#(1,f_prec))));
   
   // constants
   Bit#(idx_sz) bpskSz = fromInteger(valueOf(xxB)-1);
   Bit#(idx_sz) qpskSz = fromInteger(valueOf(xxC)-1);
   Bit#(idx_sz) qam16Sz = fromInteger(valueOf(xxD)-1);
   Bit#(idx_sz) qam64Sz = fromInteger(valueOf(xxE)-1);
		      
   // state elements
   Reg#(Bit#(idx_sz)) counter <- mkReg(0);
   FIFO#(DemapperMesg#(ctrl_t,i_n,i_prec,f_prec)) inQ <- mkLFIFO;
   FIFO#(DeinterleaverMesg#(ctrl_t,o_n,ViterbiMetric)) outQ <- mkSizedFIFO(1);
   
   // rules
   rule demap(True);
      let inData = inQ.first.data; 
      let ctrl = inQ.first.control;
      let format = mapCtrl(ctrl);
      let checkSz = case(format)
		       BPSK: bpskSz;
		       QPSK: qpskSz;
		       QAM_16: qam16Sz;
		       QAM_64: qam64Sz;
		    endcase;
      Vector#(o_n, ViterbiMetric) outData = newVector;
      Vector#(xxB,Vector#(o_n,FPComplex#(i_prec,f_prec)))     bpskVec  = unpackVec(inData); 
      Vector#(xxC,Vector#(qpsk_n,FPComplex#(i_prec,f_prec)))  qpskVec  = unpackVec(inData); 
      Vector#(xxD,Vector#(qam16_n,FPComplex#(i_prec,f_prec))) qam16Vec = unpackVec(inData); 
      Vector#(xxE,Vector#(qam64_n,FPComplex#(i_prec,f_prec))) qam64Vec = unpackVec(inData); 
      outData = case (format)
		   BPSK:   map(decodeBPSK(negateOutput),bpskVec[counter]);
		   QPSK:   packVec(map(decodeQPSK(negateOutput),qpskVec[counter]));
		   QAM_16: packVec(map(decodeQAM_16(negateOutput),qam16Vec[counter]));
		   QAM_64: packVec(map(decodeQAM_64(negateOutput),qam64Vec[counter]));
		endcase;
      outQ.enq(Mesg{control: ctrl, data: outData});
      if(`DEBUG_DEMAPPER == 1)
         begin
            Vector#(o_n, Int#(SizeOf#(ViterbiMetric))) intData = unpack(pack(outData));      
            case (format)
               BPSK: for (Integer i = 0; i < valueOf(o_n); i=i+1)
                        begin
                           $write("Demapper map %d bpsk data",i);
                           fpcmplxWrite(5, bpskVec[counter][i]);
                           $display(" -> %d",inData[i]);                         
                        end
               QPSK: for (Integer i = 0; i < valueOf(qpsk_n); i=i+1)
                        begin
                           $write("Demapper map %d qpsk data",counter*fromInteger(valueOf(qpsk_n)+i));
                           fpcmplxWrite(5, qpskVec[counter][i]);
                           $display(" -> %d, %d",inData[2*i],inData[2*i+1]);                         
                        end
               QAM_16: for (Integer i = 0; i < valueOf(qam16_n); i=i+1)
                          begin
                             $write("Demapper map %d 16-qam data",counter*fromInteger(valueOf(qam16_n)+i));
                             fpcmplxWrite(5, qam16Vec[counter][i]);
                             $display(" -> %d, %d, %d, %d",
                                      inData[4*i],
                                      inData[4*i+1],
                                      inData[4*i+2],
                                      inData[4*i+3]);                         
                          end
               QAM_64: for (Integer i = 0; i < valueOf(qam64_n); i=i+1)
                          begin
                             $write("Demapper map %d 64-qam data",counter*fromInteger(valueOf(qam64_n)+i));
                             fpcmplxWrite(5, qam64Vec[counter][i]);
                             $display(" -> %d, %d, %d, %d, %d, %d",
                                      inData[6*i],
                                      inData[6*i+1],
                                      inData[6*i+2],
                                      inData[6*i+3],
                                      inData[6*i+4],
                                      inData[6*i+5]);                         
                          end
            endcase
         end
      if (counter == checkSz)
	 begin
	    inQ.deq;
	    counter <= 0;
	 end
      else
	 counter <= counter + 1;
   endrule

   // methods
   interface  in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);
endmodule // mkDemapper      






