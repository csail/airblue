import Complex::*;
import FIFOF::*;
import FixedPoint::*;
import GetPut::*;
import Vector::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_special_fifos.bsh"

import "BDPI" function ActionValue#(FPComplex#(2,14)) 
    awgn(FPComplex#(2,14) data);

import "BDPI" function ActionValue#(FPComplex#(2,14))
    rayleigh_channel(FPComplex#(2,14) data, Bit#(32) cycle);

import "BDPI" function ActionValue#(FPComplex#(2,14))
    cfo(FPComplex#(2,14) data, Bit#(32) cycle);

import "BDPI" function Bool isset(String name);


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

   StreamFIFO#(80, 7, FPComplex#(2,14)) queue <- mkStreamFIFO;

   Reg#(Bit#(32)) cycle <- mkReg(0);
 
   Reg#(Bool) init <- mkReg(False);
 
   // additive white gaussian noise
   Reg#(Bool) enableNoise <- mkReg(False);
 
   // rayleigh fading channel
   Reg#(Bool) enableFading <- mkReg(False);
 
   // carrier frequency offset
   Reg#(Bool) enableCFO <- mkReg(False);
 
   rule initialize (!init);
      init <= True;
      enableNoise <= isset("ADDNOISE_SNR");
      enableFading <= isset("JAKES_DOPPLER");
      enableCFO <= isset("CHANNEL_CFO");
   endrule

   method Action enq(Bit#(7) size, Vector#(64, FPComplex#(2,14)) data);
      for (Integer n = 0; fromInteger(n) < size; n=n+1)
        begin
          Bit#(32) i = fromInteger(n);

          if (enableCFO)
             data[i] <- cfo(data[i], cycle + i);
     
          if (enableFading)
             data[i] <- rayleigh_channel(data[i], cycle + i);
     
          if (enableNoise)
             data[i] <- awgn(data[i]);
        end

      cycle <= cycle + extend(size);
      queue.enq(extend(size), append(data, ?));
   endmethod

   method Action deq(Bit#(7) size);
       queue.deq(size);
   endmethod

   method Vector#(64, FPComplex#(2,14)) first;
      return take(queue.first);
   endmethod

   method Bool notEmpty(Bit#(7) size);
      return queue.notEmpty(size);
   endmethod

   method Bool notFull(Bit#(7) size);
      return queue.notFull(size);
   endmethod

endmodule
