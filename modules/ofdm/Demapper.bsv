import Complex::*;
import FIFO::*;
import FixedPoint::*;
import Vector::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
// import VectorLibrary::*;

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
	    Mul#(xxB,o_n,i_n),
	    Mul#(xxC,qpsk_n,i_n),
	    Mul#(xxD,qam16_n,i_n),
	    Mul#(xxE,qam64_n,i_n),
	    Log#(i_n,idx_sz));
   
   // constants
   Bit#(idx_sz) bpskSz = fromInteger(valueOf(xxB)-1);
   Bit#(idx_sz) qpskSz = fromInteger(valueOf(xxC)-1);
   Bit#(idx_sz) qam16Sz = fromInteger(valueOf(xxD)-1);
   Bit#(idx_sz) qam64Sz = fromInteger(valueOf(xxE)-1);
		      
   // state elements
   Reg#(Bit#(idx_sz)) counter <- mkReg(0);
   FIFO#(DemapperMesg#(ctrl_t,i_n,i_prec,f_prec)) inQ <- mkLFIFO;
   FIFO#(DeinterleaverMesg#(ctrl_t,o_n,ViterbiMetric)) outQ <- mkSizedFIFO(2);
   
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






