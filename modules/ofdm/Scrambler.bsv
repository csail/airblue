import DataTypes::*;
import Interfaces::*;
import Controls::*;
import FIFO::*;
import GetPut::*;
import LibraryFunctions::*;
import Vector::*;

function a choose(Bool b, a x, a y);
   return b ? x : y;
endfunction

function Tuple2#(Bit#(1),Bit#(shifter_sz)) 
   scramble(Bit#(shifter_sz) genPoly,
	    Tuple2#(Bit#(1),Bit#(shifter_sz)) tup,
	    Bit#(1) inBit)
   provisos (Add#(1,xxA,shifter_sz));
   let curSeq = tpl_2(tup);
   let fback = genXORFeedback(genPoly,curSeq);
   Vector#(shifter_sz,Bit#(1)) oVec = shiftInAt0(unpack(curSeq),fback);
   let oSeq = pack(oVec);
   let oBit = fback ^ inBit;
   return tuple2(oBit,oSeq);
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
   Reg#(Bit#(shifter_sz)) shiftReg <- mkRegU;
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










