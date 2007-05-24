import GetPut::*;
import FIFO::*;
//import ReedTypes::*;
//import Arith::*;
//import SyndromeParallel::*;
//import Berlekamp::*;
//import ChienErrMag::*;
//import ErrorCorrector::*;
//import IReedSolomon::*;

import ofdm_reed_types::*;
import ofdm_reed_arith::*;
import ofdm_reed_common::*;


// Uncomment line below which defines BUFFER_LENGTH if   
// you get a compile error regarding BUFFER_LENGTH       

`define BUFFER_LENGTH   435

(* synthesize *)
module mkReedSolomon#(Polynomial primitive_poly) (IReedSolomon);

   ISyndrome         syndrome          <- mkSyndromeParallel (primitive_poly);
   IBerlekamp        berl              <- mkBerlekamp (primitive_poly);
   IChienErrMag      chien_errmag      <- mkChienErrMag (primitive_poly);
   IErrorCorrector   error_corrector   <- mkErrorCorrector ();

   FIFO#(Byte)    t_in                 <- mkFIFO ();
   FIFO#(Byte)    k_in                 <- mkFIFO ();
   FIFO#(Byte)    stream_in            <- mkFIFO ();
   FIFO#(Byte)    stream_out           <- mkFIFO ();
   FIFO#(Bool)    cant_correct_out     <- mkFIFO ();

   FIFO#(Byte)    ff_r_to_syndrome     <- mkFIFO ();
   FIFO#(Byte)    ff_t_to_syndrome     <- mkFIFO ();
   FIFO#(Bool)    ff_no_error_flag_to_berlekamp    <- mkFIFO ();
   FIFO#(Bool)    ff_no_error_flag_to_chien        <- mkFIFO ();
   FIFO#(Bool)    ff_no_error_flag_to_errorcor     <- mkFIFO ();

   FIFO#(Byte)    ff_s_to_berlekamp    <- mkFIFO ();
   FIFO#(Byte)    ff_t_to_berlekamp    <- mkFIFO ();

   FIFO#(Byte)    ff_l_to_chien        <- mkFIFO ();
   FIFO#(Byte)    ff_w_to_chien        <- mkFIFO ();
   FIFO#(Byte)    ff_t_to_chien        <- mkFIFO ();
   FIFO#(Byte)    ff_k_to_chien        <- mkFIFO ();

   FIFO#(Byte)    ff_e_to_errorcor     <- mkFIFO ();
   FIFO#(Byte)    ff_r_to_errorcor     <- mkSizedFIFO (`BUFFER_LENGTH);
   FIFO#(Byte)    ff_t_to_errorcor     <- mkFIFO ();
   FIFO#(Byte)    ff_k_to_errorcor     <- mkFIFO ();
   
   Reg#(Byte)     padding_zeros        <- mkReg (0);
   Reg#(Bool)     padding_zeros_done   <- mkReg (True);
   Reg#(Bool)     info_count_done      <- mkReg (True);
   Reg#(Bool)     parity_count_done    <- mkReg (True);
   Reg#(Byte)     state                <- mkReg (0);
   Reg#(Bit#(32)) cycle_count          <- mkReg (0);
   Reg#(Byte)     info_count           <- mkReg (0);
   Reg#(Byte)     parity_count         <- mkReg (0);



   // ----------------------------------
   rule init (state == 0);
      state <= 1;
   endrule
   

   // ----------------------------------
   rule read_mac (state == 1 && info_count_done == True && parity_count_done == True);
      let k = k_in.first ();
      k_in.deq ();
      info_count <= k;
      // k = 0, means no info bytes, stupid special case!
      if (k == 0)
         info_count_done <= True;
      else
         info_count_done <= False;
      ff_k_to_chien.enq (k);
      ff_k_to_errorcor.enq (k);

      let t = t_in.first ();
      t_in.deq ();
      ff_t_to_syndrome.enq (t);
      ff_t_to_berlekamp.enq (t);
      ff_t_to_chien.enq (t);
      ff_t_to_errorcor.enq (t);

      parity_count <= 2 * t ;
      if (t == 0)
         parity_count_done <= True;
      else
         parity_count_done <= False;
      
      let number_padding_zeros = 255 - k - 2*t;
      padding_zeros <= number_padding_zeros;
      if (number_padding_zeros == 0)
         padding_zeros_done <= True;
      else
         padding_zeros_done <= False;
	 
      $display ("  [reedsol] read_mac z = %d, k = %d, t = %d", 255 - k - 2*t, k, t);
   endrule

   rule pad_zeros (state == 1 && padding_zeros_done == False);
      $display ("  [reedsol]  pad_zeros [%d]", padding_zeros);
      ff_r_to_syndrome.enq (0);
      padding_zeros <= padding_zeros - 1;
      if (padding_zeros == 1)
         padding_zeros_done <= True;
   endrule


   rule read_input (state == 1 && padding_zeros_done == True && info_count_done == False);
      let datum = stream_in.first ();
      $display ("  [reedsol]  read_input [%d] = %d", info_count, datum);
      stream_in.deq ();
      ff_r_to_syndrome.enq (datum);
      ff_r_to_errorcor.enq (datum);
      if (info_count == 1)
         info_count_done <= True;
      info_count <= info_count - 1;
   endrule
   

   rule read_parity (state == 1 && padding_zeros_done == True && info_count_done == True && parity_count_done == False);
      let datum = stream_in.first ();
      $display ("  [reedsol]  read_pairty [%d] = %d", parity_count, datum);
      stream_in.deq ();
      ff_r_to_syndrome.enq (datum);
      if (parity_count == 1)
         parity_count_done <= True;
      parity_count <= parity_count - 1;
   endrule

   // ----------------------------------
   rule t_to_syndrome (state == 1);
      // $display ("    > > [t to syndrome] cycle count: %d", cycle_count);
      ff_t_to_syndrome.deq ();
      let datum = ff_t_to_syndrome.first ();
      syndrome.t_in (datum);
   endrule

   rule r_to_syndrome (state == 1);
      // $display ("    > > [r to syndrome] cycle count: %d", cycle_count);
      ff_r_to_syndrome.deq ();
      let datum = ff_r_to_syndrome.first ();
      syndrome.r_in (datum);
   endrule

   rule s_from_syndrome (state == 1);
      // $display ("    > > [s from syndrome] cycle count: %d", cycle_count);
      let datum <- syndrome.s_out ();
      ff_s_to_berlekamp.enq (datum);
   endrule


   rule flag_from_syndrome (state == 1);
      // $display ("    > > [no error flag from syndrome] cycle count: %d", cycle_count);
      let no_error <- syndrome.no_error_flag_out ();
      ff_no_error_flag_to_berlekamp.enq (no_error);
      ff_no_error_flag_to_chien.enq (no_error);
      ff_no_error_flag_to_errorcor.enq (no_error);
   endrule


   // ----------------------------------
   rule s_to_berlekamp (state == 1);
      // $display ("    > > [s to berlekamp] cycle count: %d", cycle_count);
      ff_s_to_berlekamp.deq ();
      let datum = ff_s_to_berlekamp.first ();
      berl.s_in (datum);
   endrule

   rule t_to_berlekamp (state == 1);
      // $display ("    > > [t to berlekamp] cycle count: %d", cycle_count);
      ff_t_to_berlekamp.deq ();
      let datum = ff_t_to_berlekamp.first ();
      berl.t_in (datum);
   endrule

   rule no_error_flag_to_berlekamp (state == 1);
      // $display ("    > > [no_error to berlekamp] cycle count: %d", cycle_count);
      ff_no_error_flag_to_berlekamp.deq ();
      let no_error = ff_no_error_flag_to_berlekamp.first ();
      berl.no_error_flag_in (no_error);
   endrule

   
   rule l_from_berlekamp (state == 1);
      // $display ("    > > [l from berlekamp] cycle count: %d", cycle_count);
      let datum <- berl.lambda_out ();
      ff_l_to_chien.enq (datum);
   endrule

   rule w_from_berlekamp (state == 1);
      // $display ("    > > [w from berlekamp] cycle count: %d", cycle_count);
      let datum <- berl.omega_out ();
      ff_w_to_chien.enq (datum);
   endrule


   // ----------------------------------
   rule l_to_chien (state == 1);
      // $display ("    > > [l to chien] cycle count: %d", cycle_count);
      ff_l_to_chien.deq ();
      let datum = ff_l_to_chien.first ();
      chien_errmag.lambda_in (datum);
   endrule

   rule w_to_chien (state == 1);
      // $display ("    > > [w to chien] cycle count: %d", cycle_count);
      ff_w_to_chien.deq ();
      let datum = ff_w_to_chien.first ();
      chien_errmag.omega_in (datum);
   endrule

   rule t_to_chien (state == 1);
      // $display ("    > > [t to chien] cycle count: %d", cycle_count);
      ff_t_to_chien.deq ();
      let datum = ff_t_to_chien.first ();
      chien_errmag.t_in (datum);
   endrule

   rule k_to_chien (state == 1);
      ff_k_to_chien.deq ();
      let datum = ff_k_to_chien.first ();
      chien_errmag.k_in (datum);
   endrule

   rule no_error_flag_to_chien (state == 1);
      // $display ("    > > [no_error to chien] cycle count: %d", cycle_count);
      ff_no_error_flag_to_chien.deq ();
      let no_error = ff_no_error_flag_to_chien.first ();
      chien_errmag.no_error_flag_in (no_error);
   endrule
   
   rule e_from_chien (state == 1);
      // $display ("    > > [e from chien] cycle count: %d", cycle_count);
      let datum <- chien_errmag.error_out ();
      ff_e_to_errorcor.enq (datum);
   endrule
   
   rule flag_from_chien (state == 1);
      // $display ("    > > [flag from chien] cycle count: %d", cycle_count);
      let datum <- chien_errmag.cant_correct_flag_out ();
      cant_correct_out.enq (datum);
   endrule

   // ----------------------------------
    rule t_to_error_corrector (state == 1);
       // $display ("    > > [t to error_corrector] cycle count: %d", cycle_count);
       ff_t_to_errorcor.deq ();
       let datum = ff_t_to_errorcor.first ();
       error_corrector.t_in (datum);
    endrule

    rule k_to_error_corrector (state == 1);
       // $display ("    > > [t to error_corrector] cycle count: %d", cycle_count);
       ff_k_to_errorcor.deq ();
       let datum = ff_k_to_errorcor.first ();
       error_corrector.k_in (datum);
    endrule

    rule no_error_flag_to_error_corrector (state == 1);
       // $display ("    > > [no_error to error_corrector] cycle count: %d", cycle_count);
       ff_no_error_flag_to_errorcor.deq ();
       let no_error = ff_no_error_flag_to_errorcor.first ();
       error_corrector.no_error_flag_in (no_error);
    endrule


   rule r_to_error_corrector (state == 1);
      // $display ("    > > [r to error corrector] cycle count: %d", cycle_count);
      ff_r_to_errorcor.deq ();
      let datum = ff_r_to_errorcor.first ();
      error_corrector.r_in (datum);
   endrule
   
   rule e_to_error_corrector (state == 1);
      // $display ("    > > [e to error corector] cycle count: %d", cycle_count);
      ff_e_to_errorcor.deq ();
      let error = ff_e_to_errorcor.first ();
      error_corrector.e_in (error);
   endrule
   
   rule d_from_error_corrector (state == 1);
      // $display ("    > > [d from error corector] cycle count: %d", cycle_count);
      let corrected_datum <- error_corrector.d_out ();
      stream_out.enq (corrected_datum);
   endrule
   
   // ----------------------------------
   rule cycle (state == 1);
      $display ("%d  -------------------------", cycle_count);
      cycle_count <= cycle_count + 1;
   endrule
   
   interface Put rs_t_in     = fifoToPut (t_in);
   interface Put rs_k_in     = fifoToPut (k_in);
   interface Put rs_input    = fifoToPut (stream_in);
   interface Get rs_output   = fifoToGet (stream_out);
   interface Get rs_flag     = fifoToGet (cant_correct_out);
      
endmodule

