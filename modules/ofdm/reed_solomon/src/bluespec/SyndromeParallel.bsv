import Arith::*;
import ReedTypes::*;
import Vector::*;
import GetPut::*;

// ---------------------------------------------------------
// Reed-Solomon Syndrome calculator interface 
// ---------------------------------------------------------
interface ISyndrome;
   method Action              r_in (Byte datum);
   method ActionValue#(Byte)  s_out ();
   method Action              t_in (Byte t_new);
   method ActionValue#(Bool)  no_error_flag_out ();
endinterface

typedef Vector#(n,Byte) Syndrome#(numeric type n);


function Bool isNoError (Byte valid_t, Tuple2#(Integer, Byte) x);
   //     (2*t <= i) || (syn [i] == 0)
   return (valid_t <= (fromInteger (tpl_1(x)) >> 1)) || (tpl_2(x) == 0);
endfunction


function Bool noError (Byte valid_t, Syndrome#(32) syndrome);
   Vector#(32,Bool) no_errors = map(isNoError(valid_t), zip(genVector,syndrome)); 
   return fold(\&& , no_errors);
endfunction 


// ---------------------------------------------------------
// Reed-Solomon Syndrome calculation module 
// ---------------------------------------------------------
//(* synthesize *)
module mkSyndromeParallel#(Polynomial primitive_poly) (ISyndrome);

   Vector#(32, Reg#(Byte)) syndrome       <- replicateM (mkReg (0));
   Reg#(Maybe#(Byte))      t              <- mkReg (Invalid);
   Reg#(Byte)              n              <- mkReg (0);
   Reg#(Byte)              syndrome_read  <- mkReg (2 * t_param);
   Reg#(Byte)              block_number   <- mkReg (0);
   Reg#(Maybe#(Bool))      no_error       <- mkReg (Invalid);


   // ------------------------------------------------
   method Action r_in (Byte datum) if (n < n_param &&& t matches tagged Valid .valid_t);

      $display ("  [syndrome %d]  r_in (%d): %d", block_number, n, datum);
      Syndrome#(32) syndrome_temp = replicate (0);
      
      for (Byte x = 0; x < 2 * t_param; x = x + 1)
	   begin
         syndrome_temp [x] = times_alpha_n (primitive_poly, syndrome [x] , x + 1) ^ datum;
         syndrome [x] <= syndrome_temp [x];
	   end
      n <= n + 1;
      if (n == n_param - 1)
	   begin
	      Bool no_error_temp = noError (valid_t, syndrome_temp);
         if (no_error_temp == False)
            syndrome_read <= 0;

	      no_error <= Valid (no_error_temp);
	   end
      
   endmethod


   // ------------------------------------------------
   method ActionValue#(Byte) s_out () if (t matches tagged Valid .valid_t 
                                          &&& syndrome_read < 2 * valid_t);

      $display ("  [syndrome %d]  s_out (%d): %d", block_number, syndrome_read, syndrome [syndrome_read]);
      syndrome_read <= syndrome_read + 1;
      if (syndrome_read == 2 * valid_t - 1)
      begin
         n <= 0;
         no_error <= Invalid;
         t <= Invalid;
         block_number <= block_number + 1;
      end
      return  syndrome [syndrome_read];

   endmethod


   // ------------------------------------------------
   method Action t_in (Byte t_new) if (t == Invalid);
      $display ("  [syndrome %d]  t_in : %d", block_number, t_new);
      t <=  Valid (t_new);
	   syndrome_read <= 2*t_new;

      for (Byte x = 0; x < 2 * t_param; x = x + 1)
      begin
         syndrome [x] <= 0;
      end
   endmethod
   

   // ------------------------------------------------
   method ActionValue#(Bool) no_error_flag_out () if (no_error matches tagged Valid .valid_no_error);
     if (valid_no_error == True)
	  begin
	    n <= 0;
       t <= Invalid;
       block_number <= block_number + 1;
	  end
     no_error <= Invalid;

     return valid_no_error;
   endmethod


endmodule



