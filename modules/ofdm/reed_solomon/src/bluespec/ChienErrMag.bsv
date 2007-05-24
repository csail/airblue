import Vector::*;
import GetPut::*;
import FIFO::*;

import ofdm_reed_types::*;
import ofdm_reed_arith::*;

typedef enum 
{ 
   INIT,
   LAMBDA_RECD, 
   EVAL_POLY,
   ERR_DONE
} ChienErrMagStage deriving (Bits, Eq);


// ---------------------------------------------------------
// Reed-Solomon Chien Error Magnitude computer interface 
// ---------------------------------------------------------
interface IChienErrMag;
   method Action              t_in (Byte t_new);
   method Action              k_in (Byte k_new);
   method Action              no_error_flag_in (Bool no_error);
   method Action              lambda_in (Byte lambda_new);
   method Action              omega_in (Byte omega_new);
   method ActionValue#(Byte)  error_out ();
   method ActionValue#(Bool)  cant_correct_flag_out ();
endinterface


// ---------------------------------------------------------
// Reed-Solomon Chien Error Magnitude computer module 
// ---------------------------------------------------------
//(* synthesize *)
(* descending_urgency = "process_error, process_no_error, calc_loc" *)
module mkChienErrMag#(Polynomial primitive_poly) (IChienErrMag);

   Reg# (Maybe#(Byte))                 t                 <- mkReg (Invalid);
   Reg# (Maybe#(Byte))                 k                 <- mkReg (Invalid);
   Reg# (Byte)                         lambda_received   <- mkReg (0);
   Reg# (Byte)                         omega_received    <- mkReg (0);
   Vector# (16, Reg#(Byte))            lambda            <- replicateM (mkReg (0));
   Vector# (16, Reg#(Byte))            omega             <- replicateM (mkReg (0));
   Reg#(Maybe#(Byte))                  err_out           <- mkReg (Invalid);
   Reg# (Byte)                         err_read          <- mkReg (n_param);
   Reg# (Byte)                         omega_val         <- mkReg (0);
   Reg# (Byte)                         lambda_d_val      <- mkReg (0);

   Vector# (16, Reg#(Byte))            lambda_a          <- replicateM (mkReg (0));
   Reg# (Byte)                         i                 <- mkReg (254);
   Reg# (Byte)                         count_l           <- mkReg (0);
   Reg# (Byte)                         count_w           <- mkReg (0);
   Reg# (Byte)                         count_error       <- mkReg (0);
   Reg# (Byte)                         j                 <- mkReg (?);
   Reg# (Bool)                         calc_loc_end      <- mkReg (False);
   Reg# (Maybe#(Bool))                 cant_correct_flag <- mkReg (Invalid);
   Reg# (Maybe#(Bool))                 no_error_flag     <- mkReg (Invalid);
   Reg# (ChienErrMagStage)                        stage             <- mkReg (INIT);
   Reg# (Byte)                         block_number      <- mkReg (0);
   Reg# (Byte)                         alpha_inv_squared <- mkReg (0);
   Reg# (Byte)                         alpha_inv_j	      <- mkReg (2);
   Reg# (Byte)                         alpha_inv_squared_j<-mkReg (4);
   Reg# (Byte)                         alpha_lambda      <- mkReg (2);

   FIFO#(Bit#(1))                     loc                <- mkSizedFIFO (256);
   FIFO#(Byte)                        err                <- mkFIFO();
 
   // ------------------------------------------------
   rule calc_loc (t matches tagged Valid .valid_t
                  &&& k matches tagged Valid .valid_k
                  &&& lambda_received == valid_t
                  &&& calc_loc_end == False);

      $display ("  [chien %d]  calc_loc, i = %d", block_number, i);

      Byte result_location = 1;
      // For loop should run only over t received 
      for (Byte x = 0; x < t_param; x = x + 1)
         result_location = result_location ^ (lambda_a [x] & ((x < valid_t)? 8'hFF : 8'h00));
      
      for (Byte x = 0; x < t_param; x = x + 1)
         lambda_a [x] <= times_alpha_n (primitive_poly, lambda_a [x], x + 1) & ((x < valid_t)? 8'hFF : 8'h00);

      let zero_padding = (i >= valid_k + 2*valid_t);
      let parity_bytes = (i < 2*valid_t);
      let process_error = ((i < valid_k + 2*valid_t) && (i >= 2*valid_t));

      if (result_location == 0)
      begin
         count_error <= count_error + 1;
         if (parity_bytes == False)
            loc.enq (0);
      end
      else
      begin
         if (zero_padding == True)
         begin
            j <= j - 1;
            alpha_inv_j <= times_alpha (primitive_poly, alpha_inv_j);
            alpha_inv_squared_j <= times_alpha (primitive_poly, 
                                   times_alpha (primitive_poly, alpha_inv_squared_j));
         end
         else if (parity_bytes == False)
            loc.enq (1);
      end
      

      if (i == 0)
      begin
         calc_loc_end <= True;
         if (count_error == 0)
            cant_correct_flag <= Valid (True);
         else
            cant_correct_flag <= Valid (False);
      end
      else
         i <= i - 1;
   endrule


   // -----------------------------------------------
   rule eval_lambda (t matches tagged Valid .valid_t
		     &&& lambda_received == valid_t 
		     &&& count_l < t_param 
                     &&& loc.first() == 0);
      $display ("  [chien %d]  Evaluating Lambda_der i:%d count_l:%d, lambda_d_val[prev]: %d", block_number, j, count_l, lambda_d_val);

      // Derivative of Lambda is done by dropping even terms and shifting odd terms by one
      // So count is incremented by 2
      // valid_t - 2 is the index used as the final term since valid_t - 1 term gets dropped
      if ((count_l & 8'd1) == 8'd1)
	 lambda_d_val <= gf_mult (primitive_poly, lambda_d_val, alpha_inv_squared) ^ lambda [15 - count_l];
      else
	    alpha_inv_squared <= alpha_inv_squared_j;
 
      count_l <= count_l + 1;
   endrule
   

   // ------------------------------------------------
   // Include in predicate: loc [j] == 0
   rule eval_omega (t matches tagged Valid .valid_t
                    &&& omega_received == valid_t && count_w < t_param
                    &&& loc.first() == 0);
      $display ("  [chien %d]  Evaluating Omega i:%d count_w:%d, omega_val: %d", block_number, j, count_w, omega_val);
      omega_val <= gf_mult (primitive_poly, omega_val, alpha_inv_j) ^ omega [15 - count_w];
      count_w <= count_w + 1;
   endrule
   

   // ------------------------------------------------
   rule process_error (t matches tagged Valid .valid_t
			 &&& k matches tagged Valid .valid_k
 			 &&& loc.first() == 0  
			 &&& count_l == t_param 
			 &&& count_w == t_param);
      $display ("  [chien %d]  Processing location %d which is in error ", block_number, j);
      let err_val = gf_mult (primitive_poly, omega_val, gf_inv (lambda_d_val) );
      err.enq (err_val);
      count_l <= 0;
      count_w <= 0;
      lambda_d_val <= 0;
      omega_val <= 0;
      loc.deq ();
      j <= j - 1;
      alpha_inv_j <= times_alpha (primitive_poly, alpha_inv_j);
      alpha_inv_squared_j <= times_alpha (primitive_poly,
                             times_alpha (primitive_poly, alpha_inv_squared_j));
      if (j == 2*valid_t)
         stage <= ERR_DONE;
   endrule


   // ------------------------------------------------
   rule process_no_error (t matches tagged Valid .valid_t
			 &&& k matches tagged Valid .valid_k
 			 &&& loc.first() == 1);
      $display ("  [chien %d]  process location %d which has no error ", block_number, j);
      err.enq (0);
      loc.deq ();
      j <= j - 1;
      alpha_inv_j <= times_alpha (primitive_poly, alpha_inv_j);
      alpha_inv_squared_j <= times_alpha (primitive_poly, 
                             times_alpha (primitive_poly, alpha_inv_squared_j));
      if (j == 2*valid_t)
         stage <= ERR_DONE;
   endrule
     

   // ------------------------------------------------
   rule start_next_chien (stage == ERR_DONE);
      $display ("Start Next Chien ");

      // reset the lambda vector...       
      for (Byte x = 0; x < t_param; x = x + 1)
      begin
         // reset the internal lambda*alpha registers used in 
         // the calculation of the error locations.       
         lambda_a [x] <= 0;

         // reset the registers that hold the received lambda & omega values...
         lambda [x] <= 0;
         omega [x] <= 0;
      end

      stage <= INIT;
      t <= Invalid;
      k <= Invalid;
      no_error_flag <= Invalid;
      count_error <= 0;
      lambda_received <= 0;
      alpha_lambda <= 2;
      omega_received <= 0;
      lambda_d_val <= 0;
      omega_val <= 0;

      calc_loc_end <= False;
      cant_correct_flag <= Invalid;

      block_number <= block_number + 1;

   endrule

   // ------------------------------------------------
   method Action no_error_flag_in (Bool no_error) if (no_error_flag == Invalid);
      $display ("  [chien %d]  no_error_in : %d", block_number, no_error);
      no_error_flag <=  Valid (no_error);
   endmethod

   
   // ------------------------------------------------
   method Action t_in (Byte t_new) if (no_error_flag matches tagged Valid .valid_no_error
				       &&& k matches tagged Valid .valid_k				    
				       &&& t == Invalid);
      $display ("  [chien %d]  t_in : %d", block_number, t_new);
      if (valid_no_error == True)
	 begin
	    k <= Invalid;
	    no_error_flag <= Invalid;
	    cant_correct_flag <= Valid (False);
	    block_number <= block_number + 1;
	 end
      else
	 begin
	    t <= Valid (t_new);
	    i <= n_param - 1;
	    j <= n_param - 1;
	    alpha_inv_j <= 2;
	    alpha_inv_squared_j <= 4;
	    $display ("  [chien %d]  j = %d", block_number, valid_k + 2 * t_new - 1);
	 end
   endmethod
   

   // ------------------------------------------------
   method Action k_in (Byte k_new) if (k == Invalid);
      $display ("  [chien %d]  k_in : %d", block_number, k_new);
      k <=  Valid (k_new);
   endmethod
 
   
   // ------------------------------------------------
   method Action lambda_in (Byte lambda_new) if (t matches tagged Valid .valid_t
					      &&& lambda_received < valid_t 
					      &&& stage == INIT
                                              &&& no_error_flag matches tagged Valid .valid_no_error
					      &&& valid_no_error == False);
      $display ("  [chien %d]  l_in [%d]: %d", block_number, lambda_received, lambda_new);

      (lambda [lambda_received]) <= lambda_new;
      lambda_received <= lambda_received + 1;
      alpha_lambda <= times_alpha (primitive_poly, alpha_lambda);
      (lambda_a [lambda_received]) <= gf_mult (primitive_poly, lambda_new, alpha_lambda);
      
      if (lambda_received == valid_t - 1)
      begin
         $display ("  [chien %d]  All Lambda received, changing to CALC_LOC", block_number);
         count_l <= 0;
         count_w <= 0;
      end
   endmethod
   

   // ------------------------------------------------
   method Action omega_in (Byte omega_new) if (t matches tagged Valid .valid_t
					    &&& omega_received < valid_t
					    &&& stage == INIT
                                            &&& no_error_flag matches tagged Valid .valid_no_error
					    &&& valid_no_error == False);
      $display ("  [chien %d]  w_in [%d]: %d", block_number, omega_received, omega_new);

      (omega [omega_received]) <= omega_new;
      omega_received <= omega_received + 1;

      if (omega_received == valid_t - 1)
         $display ("All Omega received ");    
   endmethod
   
   // ------------------------------------------------
   method ActionValue#(Byte) error_out ();
      $display ("  [chien %d]  err_out: %d, stage : %d", block_number,  err.first(), stage);
      err.deq();
      $display ("No of Errors %d", count_error);
      
      // ------------------------------------------
      return err.first();
   endmethod
   
   method ActionValue#(Bool)   cant_correct_flag_out () if (cant_correct_flag matches tagged Valid .valid_cant_correct_flag);
      $display ("  [chien %d]  Cant Correct Flag %d", block_number, valid_cant_correct_flag);
//      if (valid_cant_correct_flag == True)
//	 begin
//	    stage <= ERR_DONE;
//	    err_read <= 255;
//	 end
      cant_correct_flag <= Invalid;
      return valid_cant_correct_flag;
   endmethod

endmodule



