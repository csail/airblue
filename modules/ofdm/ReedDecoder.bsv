import FIFO::*;
import Vector::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import DataTypes::*;
// import Interfaces::*;
// import Controls::*;

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
