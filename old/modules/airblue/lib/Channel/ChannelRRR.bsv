import Complex::*;
import FIFOF::*;
import FixedPoint::*;
import GetPut::*;
import Vector::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/rrr/client_stub_CHANNEL_RRR.bsh"
//`include "asim/rrr/server_stub_CHANNEL_RRR.bsh"

interface Channel#(type ai, type af);
   interface Put#(FPComplex#(ai, af)) in;
   interface Get#(FPComplex#(ai, af)) out;
endinterface


module [CONNECTED_MODULE] mkChannel(Channel#(2,14));

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
   method Action enq(Bit#(8) size, Vector#(64, FPComplex#(2,14)) data);
   method Action deq(Bit#(8) size);
   method Vector#(64, FPComplex#(2,14)) first;
   method Bool notFull(Bit#(8) size);
   method Bool notEmpty(Bit#(8) size);
endinterface


module [CONNECTED_MODULE] mkStreamChannel(StreamChannel);

   ClientStub_CHANNEL_RRR client_stub <- mkClientStub_CHANNEL_RRR();
   //ServerStub_CHANNEL_RRR server_stub <- mkServerStub_CHANNEL_RRR();

   StreamFIFO#(140, 8, FPComplex#(2,14)) inQ <- mkStreamFIFO;
   StreamFIFO#(140, 8, FPComplex#(2,14)) outQ <- mkStreamFIFO;

   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule putChannelReq (inQ.notEmpty(1));
      let size = min(10, inQ.usage);
      Vector#(10, Bit#(32)) data = map(pack, take(inQ.first));

      client_stub.makeRequest_Channel(
        extend(size),
        data[0], data[1], data[2], data[3], data[4],
        data[5], data[6], data[7], data[8], data[9],
        cycle
      );

      cycle <= cycle + extend(size);
      inQ.deq(size);
   endrule

   rule getChannelResp (outQ.notFull(10));
      let resp <- client_stub.getResponse_Channel();

      Vector#(10, Bit#(32)) data = newVector;
      data[0] = resp.out0;
      data[1] = resp.out1;
      data[2] = resp.out2;
      data[3] = resp.out3;
      data[4] = resp.out4;
      data[5] = resp.out5;
      data[6] = resp.out6;
      data[7] = resp.out7;
      data[8] = resp.out8;
      data[9] = resp.out9;

      Vector#(140, FPComplex#(2,14)) samples =
          append(map(unpack, data), ?);

      outQ.enq(truncate(resp.out_size), samples);
   endrule

   method Action enq(Bit#(8) size, Vector#(64, FPComplex#(2,14)) data);
      inQ.enq(extend(size), append(data, ?));
   endmethod

   method Action deq(Bit#(8) size);
       outQ.deq(size);
   endmethod

   method Vector#(64, FPComplex#(2,14)) first;
      return take(outQ.first);
   endmethod

   method Bool notEmpty(Bit#(8) size);
      return outQ.notEmpty(size);
   endmethod

   method Bool notFull(Bit#(8) size);
      return inQ.notFull(size);
   endmethod

endmodule
