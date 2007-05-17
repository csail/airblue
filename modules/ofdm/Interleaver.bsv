import Vector::*;
import FIFO::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import DataTypes::*;
// import Interfaces::*;
// import Controls::*;

function Vector#(sz,data_t) permute(function Integer getIdx(Integer k), 
				    Vector#(sz,data_t) inVec)
   provisos (Log#(sz,n));
   Integer j = 0;
   Vector#(sz,data_t) outVec = newVector;
   for(Integer i = 0; i < valueOf(sz); i = i + 1)
      begin
	 j = getIdx(i);
	 outVec[j] = inVec[i];
      end
   return outVec;	       
endfunction
   
// n must be multiple of 12
// minNcbps must be dividible by n    
module mkInterleaveBlock#(function Modulation mapCtrl(ctrl_t ctrl),
			  function Integer getIdx(Modulation m, 
						  Integer k))
   (InterleaveBlock#(ctrl_t,n,n,data_t,minNcbps))
   provisos(Mul#(6,minNcbps,maxNcbps),
	    Mul#(cntr_n,n,maxNcbps),
	    Log#(cntr_n,cntr_sz),
	    Bits#(ctrl_t,ctrl_sz),
	    Bits#(data_t,data_sz),
	    Bits#(Vector#(maxNcbps,data_t),total_sz),
	    Bits#(Vector#(cntr_n,Vector#(n,data_t)),total_sz));

   // constants
   Bit#(cntr_sz) bpskSz = fromInteger(valueOf(cntr_n)/6-1);
   Bit#(cntr_sz) qpskSz = fromInteger(valueOf(cntr_n)/3-1);
   Bit#(cntr_sz) qam16Sz = fromInteger(valueOf(cntr_n)*2/3-1);
   Bit#(cntr_sz) qam64Sz = fromInteger(valueOf(cntr_n)-1);

   // state elements
   FIFO#(Mesg#(ctrl_t,Vector#(n,data_t)))    inQ <- mkLFIFO;  
   FIFO#(Mesg#(ctrl_t,Vector#(n,data_t)))   outQ <- mkSizedFIFO(2);
   Reg#(Bit#(cntr_sz))                    inCntr <- mkReg(0);
   Reg#(Bit#(cntr_sz))                   outCntr <- mkReg(0);			     
   Reg#(ctrl_t)                         lastCtrl <- mkRegU;
   Reg#(Vector#(cntr_n,Vector#(n,data_t))) inBuffer;
   inBuffer <- mkReg(newVector);
   FIFO#(Mesg#(ctrl_t,Vector#(cntr_n,Vector#(n,data_t)))) outBufferQ;
   outBufferQ <- mkLFIFO;
   
   // rules
   rule putInput(True);
      let mesg = inQ.first;
      let ctrl = (inCntr == 0) ? 
                  mesg.control :
                  lastCtrl;
      let data = mesg.data;
      let lCtrl = mapCtrl(ctrl);
      let checkSz = case (lCtrl)
		       BPSK: bpskSz;
		       QPSK: qpskSz;
		       QAM_16: qam16Sz;
		       QAM_64: qam64Sz;
		    endcase;
      let newBuffer = inBuffer;
      newBuffer[inCntr] = data;
      Vector#(maxNcbps,data_t) permData = unpack(pack(newBuffer));      
      permData = case (lCtrl)
		    BPSK: permute(getIdx(BPSK),permData);
		    QPSK: permute(getIdx(QPSK),permData);
		    QAM_16: permute(getIdx(QAM_16),permData);
		    QAM_64: permute(getIdx(QAM_64),permData);
		 endcase;
      Vector#(cntr_n,Vector#(n,data_t)) outVec = unpack(pack(permData)); 
      inQ.deq;
      if (inCntr == checkSz)
	 begin
	    inCntr <= 0;
	    outBufferQ.enq(Mesg{control: ctrl, data: outVec});
	 end
      else
	 begin
	    lastCtrl <= ctrl;
	    inCntr <= inCntr + 1;
	    inBuffer <= newBuffer;
	 end    
   endrule
			 
   rule getOutput(True);
      let mesg = outBufferQ.first;
      let ctrl = mesg.control;
      let dataVec = mesg.data;
      let lCtrl = mapCtrl(ctrl);
      let checkSz = case (lCtrl)
		       BPSK: bpskSz;
		       QPSK: qpskSz;
		       QAM_16: qam16Sz;
		       QAM_64: qam64Sz;
		    endcase;
      let oData = dataVec[outCntr];
      outCntr <= (outCntr == checkSz)? 0 : outCntr + 1;
      outQ.enq(Mesg{control:ctrl, data: oData});
      if (outCntr == checkSz)
	    outBufferQ.deq;
   endrule
			 
   // methods
   interface in = fifoToPut(inQ);
   interface out = fifoToGet(outQ);	
endmodule
   
module mkInterleaver#(function Modulation mapCtrl(ctrl_t ctrl),
		      function Integer getIdx(Modulation m, 
					      Integer k))
   (Interleaver#(ctrl_t,n,n,minNcbps))
   provisos(Mul#(6,minNcbps,maxNcbps),
	    Mul#(cntr_n,n,maxNcbps),
	    Log#(cntr_n,cntr_sz),
	    Bits#(ctrl_t,ctrl_sz),
	    Bits#(Vector#(maxNcbps,Bit#(1)),total_sz),
	    Bits#(Vector#(cntr_n,Vector#(n,Bit#(1))),total_sz));
   
   InterleaveBlock#(ctrl_t,n,n,Bit#(1),minNcbps) block;
   block <- mkInterleaveBlock(mapCtrl,getIdx);
			 
   interface Put in;
      method Action put(InterleaverMesg#(ctrl_t,n) mesg);
	 let ctrl = mesg.control;
	 Vector#(n,Bit#(1)) data = unpack(mesg.data);
	 block.in.put(Mesg{control:ctrl,data:data});
      endmethod
   endinterface
			 
   interface Get out;
      method ActionValue#(MapperMesg#(ctrl_t,n)) get();
	 let mesg <- block.out.get;
	 return (Mesg{control:mesg.control,data:pack(mesg.data)});
      endmethod
   endinterface
endmodule
   
module mkDeinterleaver#(function Modulation mapCtrl(ctrl_t ctrl),
			function Integer getIdx(Modulation m, 
						Integer k))
   (Deinterleaver#(ctrl_t,n,n,decode_t,minNcbps))
   provisos(Mul#(6,minNcbps,maxNcbps),
	    Mul#(cntr_n,n,maxNcbps),
	    Log#(cntr_n,cntr_sz),
	    Bits#(ctrl_t,ctrl_sz),
	    Bits#(decode_t,decode_sz),
	    Bits#(Vector#(maxNcbps,decode_t),total_sz),
	    Bits#(Vector#(cntr_n,Vector#(n,decode_t)),total_sz));
      
   InterleaveBlock#(ctrl_t,n,n,decode_t,minNcbps) block;
   block <- mkInterleaveBlock(mapCtrl,getIdx);
   return block;
endmodule


