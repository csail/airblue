import Complex::*;
import FIFOF::*;
import FixedPoint::*;
import GetPut::*;

// local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

import "BDPI" function ActionValue#(FPComplex#(2,14)) awgn(FPComplex#(2,14) data);
import "BDPI" function ActionValue#(FPComplex#(2,14)) rayleigh_channel(FPComplex#(2,14) data, Bit#(32) cycle);
import "BDPI" function Bool isset(String name);

function FPComplex#(2,14) toComplex(Bit#(32) data);
  Tuple2#(Bit#(16),Bit#(16)) tpl = split(data);
  match {.img, .rel} = tpl;
  return cmplx(unpack(rel), unpack(img));
endfunction


interface Channel#(type ai, type af);
   interface Put#(FPComplex#(ai, af)) in;
   interface Get#(FPComplex#(ai, af)) out;
endinterface

    
(* synthesize *)
module mkChannel(Channel#(2,14));

  FIFOF#(FPComplex#(2,14)) inQ   <- mkSizedFIFOF(2);
  FIFOF#(FPComplex#(2,14)) outQ  <- mkSizedFIFOF(2);

  Reg#(Bit#(32)) cycle <- mkReg(0);

  Reg#(Bool) init <- mkReg(False);
  Reg#(Bool) enableNoise <- mkReg(False);
  Reg#(Bool) enableFading <- mkReg(False);

  rule initialize (!init);
     init <= True;
     enableNoise <= isset("ADDNOISE_SNR");
     enableFading <= isset("JAKES_DOPPLER");
  endrule

  rule tick;
     cycle <= cycle + 1;
  endrule

  rule processData (init);
     let data = inQ.first;

     if (enableFading)
        data <- rayleigh_channel(data, cycle);

     if (enableNoise)
        data <- awgn(data);

     outQ.enq(data);
     inQ.deq();
  endrule 
  
  interface in  = toPut(inQ);
  interface out = toGet(outQ); 
      
endmodule  
