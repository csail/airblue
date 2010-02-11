import DataTypes::*;
import FixedPoint::*;
import FIFOF::*;
import FPComplex::*;
import Complex::*;
import GetPut::*;
import RandomGen::*;

// start sending empty if nothing happen for sendEmptyThreshold cycles 
`define sendEmptyThreshold 100000

import "BDPI" addNoise =
    function Bit#(32) addNoise(Bit#(16) outReal, Bit#(16) outImag, Bit#(32) rot, Bit#(32) res);
      
function FPComplex#(2,14) transformData(FPComplex#(2,14) data, Bit#(8) rot, Bool res);
    let outR = data.rel;
    let outI = data.img;
    let transformedOutData = addNoise(pack(outR), pack(outI), zeroExtend(rot), zeroExtend(pack(res)));
    Bit#(16) re = truncate(transformedOutData);
    Bit#(16) im = tpl_1(split(transformedOutData));
    FPComplex#(2,14) transformedComplex = cmplx(unpack(re), unpack(im));
    return transformedComplex;
endfunction
       
function Get#(a) fifofToGet(FIFOF#(a) f);
   return (interface Get
              method get();
                 actionvalue
                   f.deq();
                   return f.first();
                 endactionvalue
              endmethod
           endinterface);
endfunction

function Put#(a) fifofToPut(FIFOF#(a) f);
   return (interface Put
              method put(a data);
                 action
                   f.enq(data);
                 endaction
              endmethod
           endinterface);
endfunction       

interface Channel#(type ai, type af);
   interface Put#(FPComplex#(ai, af)) in;
   interface Get#(FPComplex#(ai, af)) out;
endinterface
       
(* synthesize *)
module mkChannel(Channel#(2,14));

   // states
   FIFOF#(FPComplex#(2,14)) inQ   <- mkSizedFIFOF(2);
   FIFOF#(FPComplex#(2,14)) outQ  <- mkSizedFIFOF(2);     
   Reg#(Bit#(32))           count <- mkReg(0);
   RandomGen#(64) randGen <- mkMersenneTwister(64'hB573AE980FF1134C);
   
    
   rule sendEmpty(!inQ.notEmpty());
      if (count >= `sendEmptyThreshold)
         begin
            let randData <- randGen.genRand;
            Bit#(12) truncRandData = truncate(randData);
            FixedPoint#(2,14) fpRandData = unpack(signExtend(truncRandData));
            outQ.enq(cmplx(fpRandData,fpRandData));
//            let transformedComplex = transformData(0, 0, False);
//            outQ.enq(transformedComplex);
            //       $write("Send Empty Before: 0 + 0 i");
            //       $display("");
            //       $write("Send Empty After: ");
            //       fpcmplxWrite(4,transformedComplex);
            //       $display("");
         end
      else
         count <= count + 1;
   endrule

   rule processData(True);
//   rule processData(inQ.notEmpty());
      let transformedComplex = transformData(inQ.first(), 0, False);
      inQ.deq();
      outQ.enq(transformedComplex);
      count <= 0;
//             $write("Process Data Before: ");
//             fpcmplxWrite(4,inQ.first());
//             $display("");
//             $write("Process Data After: ");
//             fpcmplxWrite(4,transformedComplex);
//             $display("");
   endrule 
   
   interface in  = fifofToPut(inQ);
   interface out = fifofToGet(outQ); 
      
endmodule  
