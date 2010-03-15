import GetPut::*;

`include "asim/provides/airblue_common.bsh"

interface Channel#(type ai, type af);
   interface Put#(FPComplex#(ai, af)) in;
   interface Get#(FPComplex#(ai, af)) out;
endinterface
