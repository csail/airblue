import ClientServer::*;
import GetPut::*;
import Vector::*;

typedef Server#(Bit#(length), Bit#(TAdd#(1,TLog#(length)))) MagnitudeEstimator#(numeric type length);

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