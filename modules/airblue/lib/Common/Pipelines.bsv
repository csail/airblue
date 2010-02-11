//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
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

import FIFO::*;
import FIFOF::*;
import Vector::*;

interface Pipeline#(type alpha);
  method Action put(alpha x);
  method ActionValue#(alpha) get();
endinterface

function alpha repeatfunction(Integer reps,  function alpha f(Bit#(b) stage, alpha fx),Bit#(b) stage, alpha in );
      alpha new_in = in;
      for (Integer i = 0 ; i < reps ; i = i + 1)
	new_in    = f(stage + fromInteger(i), new_in);
      return new_in;
endfunction // alpha

// numStages = no of stages need to be executed, need to be multiple of step
// step = no of stages perform per atomic action
module mkPipeline_Circ#(Integer numStages,
                        Integer step,
                        function alpha sf(Bit#(b) s, alpha x))
       (Pipeline#(alpha))
    provisos
       (Bits#(alpha, asz));
  
			  
  // input queue
  FIFOF#(alpha)      inputQ <- mkLFIFOF();
  
  // internal state
  Reg#(Bit#(b))       stage <- mkReg(0);
  Reg#(alpha)             s <- mkRegU;  
  
  // output queue
  FIFO#(alpha)      outputQ <- mkLFIFO();
  
  rule compute(True);

      // get input (implicitly stalls if no input)

      alpha s_in = s;
      Bit#(b) maxStageIdx = fromInteger(numStages - 1);
      Bit#(b) maxStepIdx  = fromInteger(step - 1);
      
      if (stage == 0)
        begin    
          s_in = inputQ.first();
          inputQ.deq();
	end

      //do stage

      let s_out = repeatfunction(step, sf, stage, s_in);

      // store output
  
      stage <= ((maxStageIdx - stage) <= maxStepIdx) ? 0 : stage + maxStepIdx + 1; // update stage to the starting index of the next stage

      if((maxStageIdx - stage) <= maxStepIdx)
        outputQ.enq(s_out);
      else
        s <= s_out;

  endrule 
  
// The Interface
  
   method Action put(alpha x);
     inputQ.enq(x);   
   endmethod
  
   method ActionValue#(alpha) get();
     outputQ.deq();
     return outputQ.first();
   endmethod
  
endmodule


  
// numStages = no of stages need to be executed, need to be multiple of step
// step = no of stages perform per atomic action
module mkPipeline_Sync#(Integer numStages,
                        Integer step,
                        function alpha sf(Bit#(b) s, alpha x))
  (Pipeline#(alpha))
  provisos
    (Bits#(alpha, asz),Add#(b,k,32));

      // input queue
      FIFOF#(alpha)       inputQ <- mkLFIFOF();
  
      // internal state
      // This is an over estimate of the space we need
      // we're artificially restricted because there is no
      // "reasonable way to pass a "static" parameter.
      // We will only create/initialize the used registers though.

      Vector#(TExp#(b), Reg#(Maybe#(alpha))) piperegs = newVector();

      for(Integer i = 0; i < numStages - step; i = i + step) // don't need the last on
	begin
	   let pipereg <- mkReg(Nothing);
	   Bit#(b) idx = fromInteger(i);
	   piperegs[idx] = pipereg;
	end
      
      // output queue
      FIFO#(alpha)        outputQ <- mkLFIFO();
  
      rule compute(True);
     
      for(Integer i = 0; i < numStages; i = i + step)
        begin
           //Determine Inputs
	   Bit#(b) lastStage = fromInteger(i - step); // index of last stage
	   Bit#(b) thisStage = fromInteger(i);        // index ot this stage
           Maybe#(alpha)  in = Nothing; // Default Value Is Nothing
	  
           if (i != 0)                         // Not-First Stage takes from reg
             in = (piperegs[lastStage])._read;
           else                                   
 	     if(inputQ.notEmpty) // take from queue at stage 0
               begin    
                  in = Just(inputQ.first());
                  inputQ.deq();
	       end
	  
	   alpha s_in = fromMaybe(?,in);
	   
	   //do stage
	   
           alpha s_out = repeatfunction(step, sf, thisStage, s_in);
	   
	   //deal with outputs
           if (i + step < numStages) // it's not the last stage
             (piperegs[thisStage]) <= isJust(in) ? Just(s_out): Nothing;
           else if(isValid(in)) // && stage == 2
             outputQ.enq(s_out);
	   else
	     noAction;
        end     
      
      endrule
	   
// The Interface
	
      method Action put(alpha x);
         inputQ.enq(x);   
      endmethod
	
      method ActionValue#(alpha) get();
         outputQ.deq();
         return outputQ.first();
      endmethod
	
endmodule
		     
				     
// maxStage = the index of the last stage (maxStage + 1 = num of stages need to be executed)
module mkPipeline_Comb#(Integer numStages,
                        function alpha sf(Bit#(b) s, alpha x))
       (Pipeline#(alpha))
    provisos
       (Bits#(alpha, asz));

  // input queue
  FIFOF#(alpha)       inputQ <- mkLFIFOF();
  
  // output queue
  FIFO#(alpha)        outputQ <- mkLFIFO();
  
	 
  rule compute(True);

      alpha  stage_in, stage_out;
      stage_in = inputQ.first();
      stage_out = repeatfunction(numStages, sf, 0, stage_in);
      inputQ.deq();
      outputQ.enq(stage_out);
      
   endrule	 
	   
// The Interface
  
   method Action put(alpha x);
     inputQ.enq(x);   
   endmethod
  
   method ActionValue#(alpha) get();
     outputQ.deq();
     return outputQ.first();
   endmethod
  
endmodule
