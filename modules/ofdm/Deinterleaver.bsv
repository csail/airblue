import Vector::*;
import FIFO::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;
import ofdm_interleaver::*;

module mkDeinterleaver#(function Modulation mapCtrl(ctrl_t ctrl),
			function Integer getIdx(Modulation m, 
						Integer k))
   (Deinterleaver#(ctrl_t,n,n,decode_t,minNcbps))
   provisos(Mul#(6,minNcbps,maxNcbps),
	    Mul#(cntr_n,n,maxNcbps),
	    Log#(cntr_n,cntr_sz),
	    Bits#(ctrl_t,ctrl_sz),
	    Bits#(decode_t,decode_sz),
	    Bits#(Vector#(maxNcbps,decode_t),total_sz),
	    Bits#(Vector#(cntr_n,Vector#(n,decode_t)),total_sz));
      
   InterleaveBlock#(ctrl_t,n,n,decode_t,minNcbps) block;
   block <- mkInterleaveBlock(mapCtrl,getIdx);
   return block;
endmodule
