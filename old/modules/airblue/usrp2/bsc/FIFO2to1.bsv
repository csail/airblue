
import FIFO::*;
import Clocks::*;

interface FIFO1to2#(numeric type n);
  method Action enq(Bit#(n) bits);
  method ActionValue#(Bit#(TMul#(2,n))) pop();
endinterface

module mkFIFOnto2n (FIFO1to2#(n))
  provisos (Add#(n,n,TMul#(2,n)));

  FIFO#(Bit#(n)) infifo <- mkSizedFIFO(4);
  Reg#(Bit#(n)) msb <- mkReg(0);
  Reg#(Bool) popReady <- mkReg(False);

  rule shift(!popReady);
    popReady <= True;
    infifo.deq();
    msb <= infifo.first();
  endrule

  method enq = infifo.enq;

  method ActionValue#(Bit#(TMul#(2,n))) pop() if(popReady);
    infifo.deq();
    return {msb,infifo.first};
  endmethod
endmodule


module mkFIFOnto2nToCC#(Clock sClk, Reset sRst) (FIFO1to2#(n))
  provisos (Add#(n,n,TMul#(2,n)));

  SyncFIFOIfc#(Bit#(n)) infifo <- mkSyncFIFOToCC(8,sClk,sRst);
  Reg#(Bit#(n)) msb <- mkReg(0);
  Reg#(Bool) popReady <- mkReg(False);

  rule shift(!popReady);
    popReady <= True;
    infifo.deq();
    msb <= infifo.first();
  endrule

  method enq = infifo.enq;

  method ActionValue#(Bit#(TMul#(2,n))) pop() if(popReady);
    infifo.deq();
    return {msb,infifo.first};
  endmethod
endmodule


(*synthesize*)
module mkFIFO16to32 (FIFO1to2#(16));
  let m <- mkFIFOnto2n;
  return m;
endmodule

(*synthesize*)
module mkFIFO1to2 (FIFO1to2#(1));
  let m <- mkFIFOnto2n;
  return m;
endmodule

(*synthesize*)
module mkFIFO16to32ToCC#(Clock sClk, Reset sRst) (FIFO1to2#(16));
  let m <- mkFIFOnto2nToCC(sClk,sRst);
  return m;
endmodule

(*synthesize*)
module mkFIFO1to2ToCC#(Clock sClk, Reset sRst) (FIFO1to2#(1));
  let m <- mkFIFOnto2nToCC(sClk,sRst);
  return m;
endmodule