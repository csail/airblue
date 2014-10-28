import Complex::*;
import FIFOF::*;
import FixedPoint::*;
import GetPut::*;
import Vector::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_special_fifos.bsh"

import "BDPI" channel_bdpi =
    function ActionValue#(FPComplex#(2,14)) channel(FPComplex#(2,14) data);


interface Channel#(type ai, type af);
   interface Put#(FPComplex#(ai, af)) in;
   interface Get#(FPComplex#(ai, af)) out;
endinterface


module mkChannel(Channel#(2,14));

   let channel <- mkStreamChannel;

   interface Put in;
      method Action put(FPComplex#(2,14) sample) if (channel.notFull(1));
         channel.enq(1, cons(sample, ?));
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(FPComplex#(2,14)) get() if (channel.notEmpty(1));
         channel.deq(1);
         return channel.first[0];
      endmethod
   endinterface
endmodule
   

interface StreamChannel;
   method Action enq(Bit#(7) size, Vector#(64, FPComplex#(2,14)) data);
   method Action deq(Bit#(7) size);
   method Vector#(64, FPComplex#(2,14)) first;
   method Bool notFull(Bit#(7) size);
   method Bool notEmpty(Bit#(7) size);
endinterface


module mkStreamChannel(StreamChannel);

   StreamFIFO#(64, 7, FPComplex#(2,14)) queue <- mkStreamFIFO;

   method Action enq(Bit#(7) size, Vector#(64, FPComplex#(2,14)) data);
      for (Integer n = 0; fromInteger(n) < size; n=n+1)
        begin
          Bit#(32) i = fromInteger(n);
          data[i] <- channel(data[i]);
       end

      queue.enq(extend(size), data);
   endmethod

   method Action deq(Bit#(7) size);
       queue.deq(size);
   endmethod

   method Vector#(64, FPComplex#(2,14)) first;
      return queue.first;
   endmethod

   method Bool notEmpty(Bit#(7) size);
      return queue.notEmpty(size);
   endmethod

   method Bool notFull(Bit#(7) size);
      return queue.notFull(size);
   endmethod

endmodule
