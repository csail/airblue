import Vector::*;
import Controls::*;

import ofdm_parameters::*;

// import Parameters::*;

function Vector#(sz, data_t) permute(function Integer getIdx(Integer k), Vector#(sz, data_t) inVec);
      Vector#(sz, data_t) outVec = newVector;
      for (Integer i = 0; i < valueOf(sz) ; i = i + 1)
	begin
	   Integer j = getIdx(i);
	   outVec[j] = inVec[i];
	end
      return outVec;
endfunction

(* noinline *)
function Vector#(192, Bit#(1)) permuteQAM64(Vector#(192,Bit#(1)) inVec);
      return permute(interleaverGetIndex(QAM_16), inVec);
endfunction // Vector
      
      
      