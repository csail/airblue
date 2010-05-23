
//typeclass Extend#(type a, type b)
//   function b extend(a value);
//endtypeclass
//
//instance Extend#(FPComplex#(ai,af), FPComplex#(bi,bf))
//  provisos ( Add#(xxi,ai,ai),
//             Add#(xxf,af,bf) );
//   function FPComplex#(bi,bf) extend(FPComplex(ai,af) a) = fxptSignExtend;
//endinstance

// an accumulator that accumulate a moving windows of sample
interface Accumulator#(numeric type length, type a, type b); // accumulate the last length items of type a (output is type b)
   method ActionValue#(b) update(a nextInput);           // add the next value to the accumulator and get the result
   method Action          clear();                           // reset the accumulator
endinterface


// implementation of an accumulator
module mkAccumulator#(function b extend(a i)) (Accumulator#(length,a,b))
   provisos (Arith#(b),
             Bits#(a,a_sz),
             Bits#(b,b_sz));

   RWire#(Tuple2#(a,b)) accumW   <- mkRWire();
   PulseWire            clearW   <- mkPulseWire();      
   Reg#(b)              accum    <- mkReg(unpack(0));
   ShiftRegs#(length,a) delaySub <- mkCirShiftRegsNoGetVec();

   rule updateState(True);
      if (clearW)
         begin
            accum <= unpack(0);
            delaySub.clear();
         end
      else
         if (isValid(accumW.wget()))
            begin
               accum <= tpl_2(validValue(accumW.wget()));
               delaySub.enq(tpl_1(validValue(accumW.wget())));
            end
   endrule                        
   
   method ActionValue#(b) update(a nextInput);
      let newAccum = accum + extend(nextInput) - extend(delaySub.first()); 
      accumW.wset(tuple2(nextInput,newAccum));
      return newAccum;
   endmethod
   
   method Action clear();
      clearW.send();
   endmethod
endmodule
