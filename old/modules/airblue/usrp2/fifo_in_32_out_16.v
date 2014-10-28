module fifo_in_32_out_16
  (   
   // Clocks
   input dsp_clk,
   input dsp_rst,

   // guarded input interface 
   input  [31:0] dat_i,
   input  enq_en_i,     // enq data to tx pipeline (en only when rdy)
   output enq_rdy_o,    // rdy to tx

   output [15:0] dat_o,
   input  deq_en_i,
   output deq_rdy_o
      );
      
   parameter  FIFOSIZE = 512;
   parameter  CNTR_WIDTH = 9;

   reg         next_rd_fst;
   wire        dsp_rst_n;
   wire [31:0] fifo_d_out;
   wire        fifo_deq_en;

   assign      dsp_rst_n = !dsp_rst;
   assign      fifo_deq_en = !next_rd_fst && deq_en_i; // if deq while already reading the both data, then deq one item
   assign      dat_o = (next_rd_fst == 1'b1) ? fifo_d_out[15:0] : fifo_d_out[31:16];

   always @(posedge dsp_clk)
     begin
        if (!dsp_rst_n)
          begin
             next_rd_fst <= 1'b1;
          end
        else
          begin
             if (deq_en_i)
               begin	
                  next_rd_fst <= !next_rd_fst;
               end
          end
     end
   
   SizedFIFO #(.p1width(32),
               .p2depth(FIFOSIZE),
               .p3cntr_width(CNTR_WIDTH)) fifo_buf
     (.CLK(dsp_clk),
      .RST_N(dsp_rst_n),
      .CLR(),
      .D_IN(dat_i),
      .ENQ(enq_en_i),
      .FULL_N(enq_rdy_o),
      .D_OUT(fifo_d_out),
      .DEQ(fifo_deq_en),
      .EMPTY_N(deq_rdy_o));

endmodule // fifo_in_32_out_16

