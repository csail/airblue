import Vector::*;
import GetPut::*;
import FIFO::*;

import ofdm_reed_types::*;
import ofdm_reed_arith::*;

// ---------------------------------------------------------
// Reed-Solomon error corrector interface 
// ---------------------------------------------------------
interface IErrorCorrector;
   method Action              r_in (Byte datum);
   method Action              e_in (Byte datum);
   method ActionValue#(Byte)  d_out ();
   method Action              t_in (Byte t_new);
   method Action              k_in (Byte k_new);
   method Action              no_error_flag_in (Bool no_error);
endinterface

// ---------------------------------------------------------
// Reed-Solomon error corrector module 
// ---------------------------------------------------------
//(* synthesize *)
module mkErrorCorrector (IErrorCorrector);

   Reg#(Maybe#(Byte))      r              <- mkReg (Invalid);
   Reg#(Maybe#(Byte))      e              <- mkReg (Invalid);
   Reg#(Maybe#(Byte))      d              <- mkReg (Invalid);
   Reg#(Maybe#(Byte))      t              <- mkReg (Invalid);
   Reg#(Maybe#(Byte))      k              <- mkReg (Invalid);
   Reg#(Maybe#(Bool))      no_error_flag  <- mkReg (Invalid);
   Reg#(Byte)              e_cnt          <- mkReg (?);
   Reg#(Byte)              block_number   <- mkReg (0);


   rule d_no_error (r matches tagged Valid .valid_r
		    &&& no_error_flag matches tagged Valid .valid_no_error
		    &&& valid_no_error == True);
      $display ("  [error corrector %d] No Error processing", block_number);
      d <= Valid (valid_r);
   endrule
   

   rule d_corrected (r matches tagged Valid .valid_r
	    	     &&& e matches tagged Valid .valid_e);
      $display ("  [error corrector %d]  Correction processing", block_number);
      d <= Valid (valid_r ^ valid_e);
   endrule
   

   // ------------------------------------------------
   method Action r_in (Byte datum) if (t matches tagged Valid .valid_t
				       &&& k matches tagged Valid .valid_k
				       &&& r == Invalid);
      $display ("  [error corrector %d]  r_in : %d)", block_number, datum);
      r <= Valid (datum);
   endmethod


   // ------------------------------------------------
   method Action e_in (Byte datum) if (t matches tagged Valid .valid_t
				       &&& k matches tagged Valid .valid_k
				       &&& e == Invalid
				       &&& no_error_flag matches tagged Valid .valid_no_error
				       &&& valid_no_error == False);
      e <= Valid (datum);
      $display ("  [error corrector %d]  Valid e_in : %d)", block_number, datum);
   endmethod


   // ------------------------------------------------
   method Action t_in (Byte t_new) if (t == Invalid);
      $display ("  [error corrector %d]  t_in : %d", block_number, t_new);
      t <=  Valid (t_new);
   endmethod
   

   // ------------------------------------------------
   method Action k_in (Byte k_new) if (k == Invalid);
      $display ("  [error corrector %d]  k_in : %d", block_number, k_new);
      k <=  Valid (k_new);
      e_cnt<=k_new;
   endmethod
 

   // ------------------------------------------------
   method Action no_error_flag_in (Bool no_error) if (t matches tagged Valid .valid_t
						      &&& k matches tagged Valid .valid_k
						      &&& no_error_flag == Invalid);
      $display ("  [error corrector %d]  no_error : %d", block_number, no_error);
      no_error_flag <=  Valid (no_error);
   endmethod


   // ------------------------------------------------
   method ActionValue#(Byte) d_out () if (d matches tagged Valid .valid_d
					  &&& k matches tagged Valid .valid_k);
      $display ("  [error corrector %d]  d_out (%d)", block_number, valid_d);

      if (e_cnt == 1)
	 begin
	    block_number <= block_number + 1;
            t <= Invalid;
            k <= Invalid;
            no_error_flag <= Invalid;
	 end
      else
	 e_cnt <= e_cnt - 1;
      
      r <= Invalid;
      e <= Invalid;
      d <= Invalid;
      return valid_d;

   endmethod

endmodule



