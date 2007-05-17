import FIFO::*;
import GetPut::*;
import Vector::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;
import ofdm_scrambler::*;

module mkDescrambler#(function ScramblerCtrl#(n,shifter_sz) 
			 mapCtrl(ctrl_t ctrl),
		      Bit#(shifter_sz) genPoly)
   (Descrambler#(ctrl_t,n,n))
   provisos(Add#(1,xxA,shifter_sz),
	    Bits#(ctrl_t,ctrl_sz));
   
   function Bit#(0) 
      descramblerConvertCtrl(ctrl_t ctrl);
      return ?;
   endfunction
			 
   let descrambler <- mkScrambler(mapCtrl,
				  descramblerConvertCtrl,
				  genPoly);
   return descrambler;
endmodule

