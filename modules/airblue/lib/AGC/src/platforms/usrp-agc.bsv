// Some useful usrp functions

import FixedPoint::*;
import Vector::*;

Real magEstIdeal = 55; // Get this empirically from our pipeline. 
typedef 4096 BitRange;
Real bitRange = fromInteger(valueof(BitRange));
  
Real voltageRange = 3.3;
Real maxVoltage = 0.2;
Real minVoltage = 1.2;
Real maxGain = 70;
Real minGain = 0;   

FixedPoint#(12,6) fxMax= fromReal(maxVoltage/voltageRange*bitRange); 
FixedPoint#(12,6) fxMin= fromReal(minVoltage/voltageRange*bitRange); 
Bit#(12) maxvalue = pack(fxptGetInt(fxMax));
Bit#(12) minvalue = pack(fxptGetInt(fxMin));
 
Real rangePerDb = (maxVoltage - minVoltage)/voltageRange/(maxGain-minGain)*bitRange;

//Lots of concrete types here :(
// change 12 into a type variable
// min could be used to make this fully parametric for linear agc
function ActionValue#(Bit#(12)) calculateGainControl(FixedPoint#(12,6) dB);
  actionvalue

   // And now for the logic
   Bit#(12) result = maxvalue;

   FixedPoint#(12,6) factor = fromReal(rangePerDb);

   if(dB > fromReal(maxGain))
     begin
       result = maxvalue;
     end
   else if(dB < fromReal(minGain))
     begin
       result = minvalue;
     end 
   else
     begin
       result = max(maxvalue,minvalue) + pack(fxptGetInt(dB * factor));
     end

  $display("Max value: %d Min value: %d %result %d", maxvalue, minvalue, result);
  $write("requested dB: ");
  fxptWrite(5, dB);
  $display("");
  $write("multiplication factor: ");
  fxptWrite(5, factor);
  $display("");

  return result;
 endactionvalue
endfunction


// Assume midpoint is 0
// We know the range is -39.5dB to + 30dB. 
/*function ActionValue#(fxptScale) calculateGainScale(Bit#(12) scaleFactor)
  provisos  (RealLiteral#(fxptScale),
             Literal#(fxptScale));
  actionvalue
  List#(Real) 
  Vector#(BitRange, Real) factors = replicate(1.0);
  Real minFactor = 0.0001;  //Remember that we live in decibel land. 
  Real stepMultiplier = 1.0135008;//10000000 ** (1/(70*rangePerDb));
  Real currentStep = minFactor;
  for(Bit#(12) i = minvalue; i >= maxvalue; i = i - 1)
    begin
      factors[i] = currentStep;
      currentStep = currentStep * stepMultiplier; 
    end
  if(scaleFactor < maxvalue || scaleFactor > minvalue)
    begin
      $display("Scale out of range");
      $finish;
    end
  $display("Scale index: %d", scaleFactor);
  return fromReal(factors[scaleFactor]);
endactionvalue
endfunction*/