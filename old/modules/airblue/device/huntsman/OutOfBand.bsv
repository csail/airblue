//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2009 Kermin Fleming, kfleming@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//


// This module is nothing more that a thin wrapper around a pair of wires 
// used for inter-board OOB signalling.  The idea is that these wire may be 
// used to send an event trigger between boards to set up more complex 
// debugging.  At some point, a more complex channel could be implemented, but
// there's no need at present.

interface OutOfBandWires;

  (* always_ready, always_enabled *) 
  method Bit#(1) externalTriggerOutput();

  (* always_enabled, always_ready *)
  method Action externalTriggerInput(Bit#(1) trigger);

endinterface

interface OutOfBand;

  method Action driveExternalTriggerOutput(Bit#(32) duration);

  method Bool sampleExternalTriggerInput(Bit#(32) duration);  

  interface OutOfBandWires oobWires;

endinterface


module mkOutOfBand (OutOfBand);
  Reg#(Bit#(32)) inputTriggerDuration <- mkReg(0);
  Reg#(Bit#(32)) outputTriggerDuration <- mkReg(0);
  RWire#(Bit#(32)) newOutputTriggerDuration <- mkRWire();

  rule decrementCounter;
    if(newOutputTriggerDuration.wget() matches tagged Valid .value)
      begin
        outputTriggerDuration <= value;
      end
    else if(outputTriggerDuration > 0)
      begin
        outputTriggerDuration <= outputTriggerDuration - 1;
      end
  endrule 

  interface OutOfBandWires oobWires;
    method Bit#(1) externalTriggerOutput();
      return (outputTriggerDuration > 0) ? 1 : 0; 
    endmethod

    // I don't really care about saturating the register...
    method Action externalTriggerInput(Bit#(1) trigger);
      inputTriggerDuration <= (trigger == 1) ? inputTriggerDuration + 1 : 0;
    endmethod
  endinterface

  method Action driveExternalTriggerOutput(Bit#(32) duration);
    newOutputTriggerDuration.wset(duration);
  endmethod

  method Bool sampleExternalTriggerInput(Bit#(32) duration);  
    return (inputTriggerDuration > duration);
  endmethod

endmodule
