import FixedPoint::*;
import FIFO::*;
import GetPut::*;
import ClientServer::*;
import Vector::*;
import Real::*;

// import MagnitudeEstimator::*;
// import ProtocolParameters::*;
// import InverseSqRootParams::*;

// Local includes
`include "asim/provides/airblue_magnitude_estimator.bsh"
`include "asim/provides/airblue_parameters.bsh"


typedef Server#(FixedPoint#(i_prec,f_prec),FixedPoint#(i_prec,f_prec)) InverseSqRoot#(numeric type i_prec, numeric type f_prec);


// This function calculates the inverse of the square root of a fixed point value
// Uses the equation U[i+1] = .5*U[i]*(3-root*U[i]^2)
// probably don't want a synth boundary here

module mkSimpleInverseSqRoot (InverseSqRoot#(i_prec,f_prec))
  provisos( 
             Add#(1,a__,TAdd#(i_prec,f_prec)),
             Add#(i_prec, f_prec, TAdd#(i_prec, f_prec)),
             Add#(1, b__, i_prec)
          );
 
  // May not be the best way to do things...
  MagnitudeEstimator#(TAdd#(i_prec,f_prec)) magnitudeEstimator <- mkMagnitudeEstimator();

  Reg#(Bit#(TLog#(TAdd#(1,ISRIterations)))) iterations <- mkReg(0);
  Reg#(FixedPoint#(i_prec,f_prec)) root <- mkRegU;
  Reg#(FixedPoint#(i_prec,f_prec)) u <- mkRegU;
  Reg#(Bool) initialized <- mkReg(False);
  FIFO#(FixedPoint#(i_prec,f_prec)) resultFIFO <- mkFIFO;
   

  function Vector#(TAdd#(i_prec,f_prec), FixedPoint#(i_prec,f_prec))  determineStartValues();
    Vector#(TAdd#(i_prec,f_prec), FixedPoint#(i_prec,f_prec)) vec = newVector;
    for(Integer i = valueof(f_prec), Real r = sqrt(2.0) ; i > 0; i = i - 1, r = r*sqrt(2.0))
      begin
        vec[i-1] = fromReal(r); 
      end
    for(Integer i = valueof(f_prec), Real r = 1.0 ; i < valueof(f_prec) + valueof(i_prec); i = i + 1, r = r/sqrt(2.0))
      begin
        vec[i] = fromReal(r); 
      end
    return vec;
  endfunction

 
  // we want a seperate rule to read out of the magnitude estimator in case 
  // it becomes multicycle
  rule setStartPoint;
    let resp <- magnitudeEstimator.response.get;
    $display("InvSqRt: Magnitude MSB %d", resp);
    u <= determineStartValues()[resp];
    initialized <= True;
  endrule

  rule estimate(iterations > 0 && initialized);
    iterations <= iterations - 1;
    if(iterations - 1 == 0) 
      begin
        initialized <= False;
        resultFIFO.enq(u);
      end
    $write("InvSqRt: Iteration %d, u", iterations);
    fxptWrite(5,u);
    $display("");
    u <= 0.5 * u *(3 - root * u * u);
  endrule

  interface Put request;
     method Action put(FixedPoint#(i_prec,f_prec) magnitude) if(iterations == 0);
       // select starting value based on       
       if(magnitude != 0)
         begin
           iterations <= fromInteger(valueof(ISRIterations)); 
           root <= magnitude; // dealing with unsigned value 
           $write("InvSqRt: magnitude ");
           fxptWrite(5,magnitude);
           $display("");
           magnitudeEstimator.request.put(pack(magnitude));
         end
       else 
         begin
           resultFIFO.enq(maxBound); // maxBound might help some
         end 
     endmethod
  endinterface

  interface Get response = fifoToGet(resultFIFO);  

endmodule