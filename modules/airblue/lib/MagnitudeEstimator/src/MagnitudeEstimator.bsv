`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/provides/fpga_components.bsh"

import ClientServer::*;
import GetPut::*;
import FixedPoint::*;
import Vector::*;
import FIFO::*;

typedef Server#(Bit#(length), Bit#(TAdd#(1,TLog#(length)))) MagnitudeEstimator#(numeric type length);

// This intended as a seed for Newton Raphson.  As such it is not massively accurate. 
module mkMagnitudeEstimator (MagnitudeEstimator#(length))
  provisos(Add#(1,a__,length));
  RWire#(Bit#(TAdd#(1,TLog#(length)))) magnitudeWire <- mkRWire;

  function takeMax(Maybe#(Bit#(TAdd#(1,TLog#(length)))) a, Maybe#(Bit#(TAdd#(1,TLog#(length)))) b);
    let retVal = tagged Invalid;
    if(a matches tagged Valid .indexA &&& b matches tagged Valid .indexB) 
      begin
        if(indexA > indexB)
          begin
            retVal = a;
          end 
        else
          begin
            retVal = b;
          end 
      end
    else if(a matches tagged Valid .indexA)
      begin
        retVal = a;
      end
    else if(b matches tagged Valid .indexB)
      begin
        retVal = b;
      end
    return retVal;
  endfunction 

  function Vector#(length,Maybe#(Bit#(TAdd#(1,TLog#(length))))) buildIndexVector(Bit#(length) value);
    Vector#(length,Maybe#(Bit#(TAdd#(1,TLog#(length))))) vecs = replicate(tagged Invalid);
    for(Integer i = 0; i <  valueof(length); i = i + 1)
       begin
         if(value[i] == 1)
           begin
             vecs[i] = tagged Valid fromInteger(i+1);
           end
         else
           begin
             vecs[i] = tagged Invalid;
           end
       end
    return vecs;
  endfunction

  interface Put request;
     method Action put(Bit#(length) value);
       let maxIndex = fold(takeMax,buildIndexVector(value));
       magnitudeWire.wset(fromMaybe(0,maxIndex)); 
     endmethod
  endinterface

  interface Get response;  
    method ActionValue#(Bit#(TAdd#(1,TLog#(length)))) get() if(magnitudeWire.wget matches tagged Valid .magnitude);
      return magnitude;
    endmethod
  endinterface
endmodule




// This module is a accurate that the previous, which is intended as a seed 
// for Newton Raphson.
module mkLookupBasedEstimator#(NumTypeParam#(bits_high) bh, NumTypeParam#(bits_low) bl) (Server#(Bit#(bIn),FixedPoint#(iOut,fOut)))
 provisos (Add#(blOff, bits_low, bIn),
           Add#(bhOff, bits_high, bIn));

  // 0 is a degenerate case.
  function calculateLogs(Real base, Integer value);
    return (value==0)?maxBound:fromReal(log10(base*fromInteger(value)));
  endfunction

  Vector#(TExp#(bits_high),FixedPoint#(iOut,fOut)) logsHigh = genWith(calculateLogs(fromInteger(valueof(TExp#(bits_low)))));
  Vector#(TExp#(bits_low),FixedPoint#(iOut,fOut)) logsLow = genWith(calculateLogs(1));
  FIFO#(Bool) chooseLow <- mkSizedFIFO(1);
  FIFO#(FixedPoint#(iOut,fOut)) highValue <- mkSizedFIFO(1);
  FIFO#(FixedPoint#(iOut,fOut)) lowValue <- mkSizedFIFO(1);

  interface Put request;
     method Action put(Bit#(bIn) value);
       Bit#(bits_low) lowMax = maxBound;
       Bit#(bits_low) lowIdx = truncate(value);
       Bit#(bits_high) highIdx = truncateLSB(value);

       lowValue.enq(logsLow[lowIdx]);
       highValue.enq(logsHigh[highIdx]);
       chooseLow.enq(value < zeroExtend(lowMax));
     endmethod
  endinterface

  interface Get response;
    method ActionValue#(FixedPoint#(iOut,fOut)) get();
      chooseLow.deq;
      lowValue.deq;
      highValue.deq;
      return (chooseLow.first)?lowValue.first:highValue.first;
    endmethod
  endinterface
endmodule