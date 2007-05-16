import Controls::*;
import DataTypes::*;
import FIFO::*;
import Interfaces::*;
import LibraryFunctions::*;
import GetPut::*;

// auxiliary function
function Tuple2#(Bit#(n), Bit#(sRegSz)) scramble(Bit#(n) inBit, Bit#(sRegSz) sReg, Bit#(sRegSz) mask)
  provisos (Add#(1,xxA,sRegSz));

      Integer sRegSzInt = valueOf(sRegSz);
      Nat sRegSzNat = fromInteger(sRegSzInt);
      Bit#(n) res = 0;
      Bit#(sRegSz) newSReg = sReg;

      for(Integer i = 0; i < valueOf(n); i = i + 1)
	begin
	   Bit#(1) temp = 0;
	   for(Integer j = 0; j < sRegSzInt; j = j + 1)
	     if (mask[j] == 1)
	       temp = temp ^ newSReg[j];
	   res[i] = inBit[i] ^ temp;
	   newSReg = {newSReg[sRegSzNat-1:1],temp};
	end

      return tuple2(res, newSReg);

endfunction

// main function
module mkDescrambler#(function DescramblerCtrl genCtrl(ctrl_t ctrl),
		      Bit#(sRegSz) mask,
		      Bit#(sRegSz) initSeq)
  (Descrambler#(ctrl_t, n))
  provisos (Add#(1, xxA, sRegSz),
	    Add#(1, xxB, n), Add#(sRegSz, xxC, n),
	    Bits#(DescramblerMesg#(ctrl_t,n), xxD));

   Reg#(Bit#(sRegSz)) sReg <- mkReg(initSeq);
   FIFO#(DescramblerMesg#(ctrl_t,n)) outQ <- mkSizedFIFO(2);
   
    interface Put in;
        method Action put(DescramblerMesg#(ctrl_t, n) inMsg);
      let ctrl = genCtrl(inMsg.control); 
      case (ctrl)
	Bypass: outQ.enq(inMsg);
	FixRst: 
	  begin
	     let res = scramble(inMsg.data, initSeq, mask);
	     outQ.enq(DescramblerMesg{ control: inMsg.control,
				       data: tpl_1(res)});
	     sReg <= tpl_2(res);
	  end
	DynRst:
	  begin
	     Tuple2#(Bit#(xxC),Bit#(sRegSz)) splittedData = split(inMsg.data);
	     let newInitSeq = reverseBits(tpl_2(splittedData));
	     let newInData = tpl_1(splittedData);
	     let res = scramble(newInData, newInitSeq, mask);
	     Bit#(n) outData = {tpl_1(res), newInitSeq};
	     outQ.enq(DescramblerMesg{ control: inMsg.control,
				       data: outData});
	     sReg <= tpl_2(res);
	  end
	Norm:
	  begin
	     let res = scramble(inMsg.data, sReg, mask);
	     outQ.enq(DescramblerMesg{ control: inMsg.control,
				       data:tpl_1(res)});
	     sReg <= tpl_2(res);
	  end
      endcase // case(inMsg.ctrl)
        endmethod
    endinterface

    interface out = fifoToGet(outQ);
endmodule // mkDescrambler         

