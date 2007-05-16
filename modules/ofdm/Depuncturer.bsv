import Controls::*;
import DataTypes::*;
import FIFO::*;
import GetPut::*;
import Interfaces::*;
import StreamFIFO::*;
import Vector::*;
import VectorLibrary::*;

typedef Vector#(r_sz,DepunctData#(c_sz))
   Depunct2DVec#(numeric type r_sz,
		 numeric type c_sz);

// for generating parallel functions
function DepunctData#(fo_sz)
   parDepunctFunc(function DepunctData#(o_sz) func(DepunctData#(i_sz) x),
		  DepunctData#(fi_sz) xs)
   provisos (Mul#(f_sz,i_sz,fi_sz),
	     Mul#(f_sz,o_sz,fo_sz));
   Integer fSz = valueOf(f_sz);
   Depunct2DVec#(f_sz,i_sz) in2DVec = unpackVec(xs);
   let out2DVec = map(func, in2DVec);
   DepunctData#(fo_sz) outVec = packVec(out2DVec);
   return outVec;
endfunction   
   
// mkPuncturer using streamFIFO
// in_buf_sz > in_sz + Max(in_sz mod {f1/f2/f3}_in_sz)
// out_buf_sz > Max({f1/f2/f3}_out_sz + ({f1/f2/f3}_out_sz mod out_sz)) 
module mkDepuncturer#(function PuncturerCtrl
		         depuncturerCtrl(ctrl_t rate),
		      function DepunctData#(f1_out_sz) 
		         twoThird(DepunctData#(f1_in_sz) x),
		      function DepunctData#(f2_out_sz)
		         threeFourth(DepunctData#(f2_in_sz) x),
		      function DepunctData#(f3_out_sz) 
		         fiveSixth(DepunctData#(f3_in_sz) x))
   (Depuncturer#(ctrl_t, in_sz, out_sz, in_buf_sz, out_buf_sz))
   provisos (Mul#(f1_sz,3,f1_in_sz),
	     Mul#(f2_sz,4,f2_in_sz),
	     Mul#(f3_sz,6,f3_in_sz),
	     Add#(xxA,in_sz,in_buf_sz),
	     Add#(xxB,f1_in_sz,in_buf_sz),
	     Add#(xxC,f2_in_sz,in_buf_sz),
             Add#(xxD,f3_in_sz,in_buf_sz),
	     Mul#(f1_sz,4,f1_out_sz),
	     Mul#(f2_sz,6,f2_out_sz),
	     Mul#(f3_sz,10,f3_out_sz),
	     Add#(xxE,out_sz,out_buf_sz),
	     Add#(xxF,in_sz,out_buf_sz),
	     Add#(xxG,f1_out_sz,out_buf_sz),
	     Add#(xxH,f2_out_sz,out_buf_sz),
	     Add#(xxI,f3_out_sz,out_buf_sz),
	     Bits#(ctrl_t,ctrl_sz),
	     Add#(in_buf_sz,1,in_buf_sz_p_1),
	     Log#(in_buf_sz_p_1,in_s_sz),
	     Add#(out_buf_sz,1,out_buf_sz_p_1),
	     Log#(out_buf_sz_p_1,out_s_sz),
	     Eq#(ctrl_t));
		       
   // constants
   Bit#(in_s_sz) inSz = fromInteger(valueOf(in_sz));
   Bit#(in_s_sz) f0InSz = inSz;
   Bit#(in_s_sz) f1InSz = fromInteger(valueOf(f1_in_sz));
   Bit#(in_s_sz) f2InSz = fromInteger(valueOf(f2_in_sz));
   Bit#(in_s_sz) f3InSz = fromInteger(valueOf(f3_in_sz));
   Bit#(out_s_sz) outSz = fromInteger(valueOf(out_sz));
   Bit#(out_s_sz) f0OutSz = fromInteger(valueOf(in_sz));		       
   Bit#(out_s_sz) f1OutSz = fromInteger(valueOf(f1_out_sz));
   Bit#(out_s_sz) f2OutSz = fromInteger(valueOf(f2_out_sz));
   Bit#(out_s_sz) f3OutSz = fromInteger(valueOf(f3_out_sz));
		       
   // state elements
   Reg#(ctrl_t) lastCtrl <- mkRegU;
   FIFO#(DecoderMesg#(ctrl_t,in_sz,ViterbiMetric)) inQ <- mkLFIFO;
   FIFO#(DecoderMesg#(ctrl_t,out_sz,ViterbiMetric)) outQ <- mkSizedFIFO(2);
   StreamFIFO#(in_buf_sz,in_s_sz,ViterbiMetric) inStreamQ <- mkStreamLFIFO;
   StreamFIFO#(out_buf_sz,out_s_sz,ViterbiMetric) outStreamQ <- mkStreamLFIFO;
      
   let inMsg = inQ.first;
   let inCtrl = inMsg.control;
   let inData = inMsg.data;
   let inPCtrl = depuncturerCtrl(inCtrl);   
   let lastPCtrl = depuncturerCtrl(lastCtrl);
   match {.fInSz, .fOutSz} = case (lastPCtrl)
				Half: tuple2(f0InSz, f0OutSz);
				TwoThird: tuple2(f1InSz,f1OutSz);
				ThreeFourth: tuple2(f2InSz,f2OutSz);
				FiveSixth: tuple2(f3InSz,f3OutSz);
			     endcase; 
   let canEnqInStreamQ = inStreamQ.notFull(inSz);
   let canDeqInStreamQ = inStreamQ.notEmpty(fInSz);
   let canEnqOutStreamQ = outStreamQ.notFull(fOutSz);
   let canDeqOutStreamQ = outStreamQ.notEmpty(outSz); 
   
   rule enqInStreamQ(canEnqInStreamQ && (lastCtrl == inCtrl || (!canDeqInStreamQ && !canDeqOutStreamQ)));
      if (lastCtrl != inCtrl)
	 lastCtrl <= inCtrl;
      inQ.deq;
      inStreamQ.enq(inSz,append(inData,newVector));
   endrule
	
   rule puncture(canDeqInStreamQ && canEnqOutStreamQ);
      let data = inStreamQ.first;
      case (lastPCtrl)
	 Half:
	 begin
	    DepunctData#(in_sz) f0InData = take(data);
	    DepunctData#(out_buf_sz) f0OutData = append(f0InData,newVector);
	    inStreamQ.deq(f0InSz);
	    outStreamQ.enq(f0OutSz,f0OutData);
	 end
	 TwoThird:
	 begin
	    DepunctData#(f1_in_sz) f1InData = take(data);
	    DepunctData#(out_buf_sz) f1OutData = append(twoThird(f1InData),newVector);
	    inStreamQ.deq(f1InSz);
	    outStreamQ.enq(f1OutSz,f1OutData);
	 end
	 ThreeFourth:
	 begin
	    DepunctData#(f2_in_sz) f2InData = take(data);
	    DepunctData#(out_buf_sz) f2OutData = append(threeFourth(f2InData),newVector);
	    inStreamQ.deq(f2InSz);
	    outStreamQ.enq(f2OutSz,f2OutData);
	 end
	 FiveSixth:
	 begin
	    DepunctData#(f3_in_sz) f3InData = take(data);
	    DepunctData#(out_buf_sz) f3OutData = append(fiveSixth(f3InData),newVector);
	    inStreamQ.deq(f3InSz);
	    outStreamQ.enq(f3OutSz,f3OutData);
	 end
      endcase
   endrule
		       
   rule deqOutStreamQ(canDeqOutStreamQ);
      DepunctData#(out_sz) outData = take(outStreamQ.first);
      let outMsg = Mesg { control: lastCtrl,
			  data: outData};
      outStreamQ.deq(outSz);
      outQ.enq(outMsg);
   endrule
   
   interface Put in = fifoToPut(inQ);
   interface Get out = fifoToGet(outQ);
   
endmodule   
   




