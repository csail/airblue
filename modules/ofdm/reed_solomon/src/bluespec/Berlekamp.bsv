import Vector::*;
import GetPut::*;

import ofdm_reed_arith::*;
import ofdm_reed_types::*;



typedef enum 
{ 
   RECEIVE_SYNDROME,
   CALC_D, 
   CALC_LAMBDA, 
   CALC_LAMBDA_C_TO_TEMP,
   CALC_LAMBDA_CALC_C,
   CALC_LAMBDA_TEMP_TO_P,
   INC_LENGTH,
   NEXT_ITERATION,
   BERLEKAMP_DONE
} BerklekampStage deriving (Bits, Eq);

// ---------------------------------------------------------
// Reed-Solomon Berlekamp algoritm interface 
// ---------------------------------------------------------
interface IBerlekamp;
   method Action              t_in (Byte t_new);
   method Action              no_error_flag_in (Bool no_error);
   method Action              s_in (Byte syndrome_new);
   method ActionValue#(Byte)  lambda_out ();
   method ActionValue#(Byte)  omega_out ();
endinterface


// ---------------------------------------------------------
// Reed-Solomon Berlekamp module 
// ---------------------------------------------------------
//(* synthesize *)
module mkBerlekamp#(Polynomial primitive_poly) (IBerlekamp);

   Reg# (Maybe#(Byte))              t                    <- mkReg (Invalid);
   Reg# (Byte)                      syndrome_received    <- mkReg (0);
   Vector# (32, Reg#(Maybe#(Byte))) syndrome             <- replicateM (mkReg (Invalid));
   Reg# (Byte)                      lambda_read          <- mkReg (0);
   Reg# (Byte)                      omega_read           <- mkReg (0);
   
   Vector# (18, Reg#(Byte))   p           <- replicateM (mkReg (0));
   Vector# (18, Reg#(Byte))   c           <- replicateM (mkReg (0));
   Vector# (18, Reg#(Byte))   w           <- replicateM (mkReg (0));
   Vector# (18, Reg#(Byte))   a           <- replicateM (mkReg (0));
   Vector# (18, Reg#(Byte))   temp_c      <- replicateM (mkReg (0));
   Vector# (18, Reg#(Byte))   temp_w      <- replicateM (mkReg (0));
   
   Reg#(Byte)                 d           <- mkReg (0);
   Reg#(Byte)                 dstar       <- mkReg (1);
   Reg#(Byte)                 d_dstar     <- mkReg (0);
   Reg#(Maybe#(Bool))         no_error_flag     <- mkReg (Invalid);

   Reg# (Byte)                i           <- mkReg (0);
   Reg# (Byte)                k           <- mkReg (0);
   Reg# (Byte)                i_k         <- mkReg (0);
   Reg# (Byte)                l           <- mkReg (0);
   Reg# (Byte)                len         <- mkReg (1);
   Reg# (Byte)                k_len       <- mkReg (0);
   Reg# (BerklekampStage)               stage       <- mkReg (RECEIVE_SYNDROME);
   Reg# (BerklekampStage)               next_stage  <- mkReg (CALC_D);
   Reg# (Byte)                block_number   <- mkReg (0);

   // ------------------------------------------------
   rule calc_d (stage == CALC_D 
               &&& syndrome [i_k] matches tagged Valid .syn
               &&& t matches tagged Valid .temp_t);
      $display ("  [berlekamp %d]  calc_d, L = %d, i = %d, k = %d, i_k = %d, len = %d", block_number, l, i, k, i_k, len);

      // This case is causing Berlekamp to freeze. What should really happen here ?
      if (k + 1 > l)
         begin
            $display ("  [berlekamp %d]  d[%d] = %d, S[%d] = %d", 
                      block_number, i, syndrome [i], i, syndrome [i]);
            d <= fromMaybe (?, syndrome [i]);
            stage <= CALC_LAMBDA;
            k <= ?;
         end
      else
      // --------------------------------------------------------------------------
      if (k + 1 == l)
         begin
            $display ("  [berlekamp %d]  d[%d] = %d, S[%d] = %d, c[%d] = %d", 
                      block_number, i, d ^ gf_mult (primitive_poly, c [k + 1], syn),
                      i_k, syn, k+1, c[k+1]);
            d <= d ^ gf_mult (primitive_poly, c [k + 1], syn);
            stage <= CALC_LAMBDA;
            k <= ?;
         end
      else
         begin 
            $display ("  [berlekamp %d]  d[%d] = %d, S[%d] = %d, c[%d] = %d", 
                      block_number, i, d ^ gf_mult (primitive_poly, c [k + 1], syn),
                      i_k, syn, k+1, c[k+1]);
            d <= d ^ gf_mult (primitive_poly, c [k + 1], syn);
            k <= k + 1;
            i_k <= i_k - 1;
         end
   endrule

   // ------------------------------------------------
   rule calc_lambda (stage == CALC_LAMBDA);
      $display ("  [berlekamp %d]  calc_lambda. d = %d, i(%d) + 1 > 2*L(%d)", block_number, d, i, l);
      if (d == 0)
      begin
         len <= len + 1;
         stage <= NEXT_ITERATION;
         $display ("  [berlekamp %d]  calc_lambda. d == 0 condition. len = %d", 
                   block_number, len + 1);
      end
      else
      begin
         if (i + 1 > 2 * l)
         begin
            stage <= CALC_LAMBDA_C_TO_TEMP;
            next_stage <= CALC_LAMBDA_TEMP_TO_P;
         end
         else
         begin
            stage <= CALC_LAMBDA_CALC_C;
            next_stage <= INC_LENGTH;
         end
       
         k <= len;
         k_len <= 0;
         d_dstar <= gf_mult (primitive_poly, d, dstar);

         $display ("  [berlekamp %d]  calc_lambda. d != 0 condition. len = %d, k = %d",
                   block_number, len, len);
      end
   endrule
   
   // ------------------------------------------------
   rule calc_lambda_c_to_temp (stage == CALC_LAMBDA_C_TO_TEMP);
      $display ("  [berlekamp %d]  swap c -> temp", block_number);
      for (int x = 0; x < 17; x = x + 1)
      begin
         temp_c [x] <= c [x];
         temp_w [x] <= w [x];
      end
      stage <= CALC_LAMBDA_CALC_C;
   endrule
   
   
   // ------------------------------------------------
   rule calc_lambda_calc_c (stage == CALC_LAMBDA_CALC_C);
      // $display ("  [berlekamp %d]  calc_lambda - calc_c. k = %d", block_number, k);
      $display ("  [berlekamp %d]  c[%d] (%d) = d_d* (%d) x p[%d] (%d)", block_number, 
                k, c [k] ^ gf_mult (primitive_poly, d_dstar, p [k_len]), d_dstar, k_len, p[k_len]);
      c [k] <= c [k] ^ gf_mult (primitive_poly, d_dstar, p [k_len]);
      w [k] <= w [k] ^ gf_mult (primitive_poly, d_dstar, a [k_len]);

      let last_iteration = ((next_stage == CALC_LAMBDA_TEMP_TO_P) && (k == l + 2)) ||
                           ((next_stage == INC_LENGTH) && (k == l + 1));
      if (last_iteration == True)
         stage <= next_stage;
      else
         begin
            k <= k + 1;
            k_len <= k_len + 1;
         end
   endrule
   
    
   
   // ------------------------------------------------
   rule inc_length (stage == INC_LENGTH);
      $display ("  [berlekamp %d]  inc len -> %d", block_number, len + 1);
      stage <= NEXT_ITERATION;
      len <= len + 1;
   endrule

  
   // ------------------------------------------------
   rule calc_lambda_temp_to_p (stage == CALC_LAMBDA_TEMP_TO_P);
      $display ("  [berlekamp %d]  swap temp -> p", block_number);
      for (int x = 0; x < 17; x = x + 1)
      begin
         p [x] <= temp_c [x];
         a [x] <= temp_w [x];
      end

      stage <= NEXT_ITERATION;
      dstar <= gf_inv (d);

      l <= i - l + 1;
      len <= 1;
   endrule
   

   // ------------------------------------------------
   rule next_iteration (stage == NEXT_ITERATION
                        &&& t matches tagged Valid .valid_t);
      $display ("  [berlekamp %d]  next iteration, i = %d", block_number, i);

      k <= 0;
      if (i == 2 * valid_t - 1)
      begin
         i <= 0;
         stage <= BERLEKAMP_DONE;
      end
      else
      begin
         i <= i + 1;
         i_k <= i;
         d <= fromMaybe (?, syndrome [i + 1]);
         stage <= CALC_D;
      end
   endrule
   
   
   // ------------------------------------------------
   rule start_next_syndrome (stage == BERLEKAMP_DONE 
                             &&& t matches tagged Valid .valid_t
                             &&& lambda_read == valid_t 
                             &&& omega_read == valid_t);
      $display ("  [berlekamp %d]  start next syndrome", block_number);
      for (int x = 0; x < 17; x = x + 1)
      begin
         p [x] <= 0;
         c [x] <= 0;
         a [x] <= 0;
         w [x] <= 0;
      end
      for (int x = 0; x < 32; x = x + 1)
         syndrome [x] <= Invalid;
      
      d <= 0;
      dstar <= 1;
      d_dstar <= 0;

      k <= 0;
      i <= 0;
      l <= 0;
      len <= 1;

      no_error_flag <= Invalid;
      t <= Invalid;
      syndrome_received <= 0;
      lambda_read <= 0;
      omega_read <= 0;
      block_number <= block_number + 1;
      // now we wait till all of the syndromes for the next block are received...
      stage <= RECEIVE_SYNDROME;

   endrule
   
   
   // ------------------------------------------------
   method Action no_error_flag_in (Bool no_error) if (no_error_flag == Invalid);
      $display ("  [berlekamp %d]  no_error_in : %d", block_number, no_error);
      no_error_flag <=  Valid (no_error);
   endmethod
   
   // ------------------------------------------------
   method Action t_in (Byte t_new) if (no_error_flag matches tagged Valid .valid_no_error
                                       &&& t == Invalid);
      $display ("  [berlekamp %d]  t_in : %d", block_number, t_new);
      if (valid_no_error)
      begin
         no_error_flag <= Invalid;
         block_number <= block_number + 1;
      end
      else
         t <=  Valid (t_new);
   endmethod
   
   
   // ------------------------------------------------
   method Action s_in (Byte syndrome_new) if (stage == RECEIVE_SYNDROME 
                                           &&& no_error_flag matches tagged Valid .valid_no_error
                                           &&& valid_no_error == False
                                           &&& t matches tagged Valid .valid_t
                                           &&& syndrome_received < 2 * valid_t);
      $display ("  [berlekamp %d]  s_in [%d]: %d", block_number, syndrome_received, syndrome_new);

      (syndrome [syndrome_received]) <= Valid (syndrome_new);
      syndrome_received <= syndrome_received + 1;

      if (syndrome_received == 0)
         d <= syndrome_new;
      
      if (syndrome_received == 2 * valid_t - 1)
      begin
         $display ("  [berlekamp %d]  all syndromes received, changing to CALC_D", block_number);    
         p [0] <= 1;
         c [0] <= 1;
         a [0] <= 1;
         w [0] <= 0;
         stage <= CALC_LAMBDA;
      end
   endmethod
   
   
   // ------------------------------------------------
   method ActionValue#(Byte)   lambda_out () if (stage == BERLEKAMP_DONE 
                                                 // &&& cant_correct_flag == False
                                                 &&& t matches tagged Valid .valid_t
                                                 &&& lambda_read < valid_t);
      $display ("  [berlekamp %d]  lambda [%d]: %d", block_number, lambda_read + 1, c [lambda_read + 1]);
      lambda_read <= lambda_read + 1;
      return c [lambda_read + 1];
   endmethod
   
   method ActionValue#(Byte)   omega_out () if (stage == BERLEKAMP_DONE 
                                                // &&& cant_correct_flag == False
                                                &&& t matches tagged Valid .valid_t
                                                &&& omega_read < valid_t);
      $display ("  [berlekamp %d]  omega [%d]: %d", block_number, omega_read + 1, w [omega_read + 1]);
      omega_read <= omega_read + 1;
      return w [omega_read + 1];
   endmethod
   
   
endmodule
