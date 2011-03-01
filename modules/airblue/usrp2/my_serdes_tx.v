`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module my_serdes_tx
  (   
   // Clocks
   input dsp_clk,
   input dsp_rst,

   // guarded input interface 
   input  [15:0] tx_dat_i,
   input  tx_klsb_i,
   input  tx_kmsb_i,
   input  tx_en,     // enq data to tx pipeline (en only when rdy)
   output tx_rdy,    // rdy to tx
      
      
   // SERDES   
   output ser_tx_clk,
   output reg [15:0] ser_t,
   output reg ser_tklsb,
   output reg ser_tkmsb
      );

   parameter  FIFOSIZE = 4;
   parameter  CNTR_WIDTH = 2;

   reg [15:0]  switch_countdown; 
   reg         send_comma;
   wire        ser_tklsb_int, ser_tkmsb_int;
   wire [15:0] ser_t_int;
   wire        dsp_rst_n;
   wire [17:0] fifo_d_out;
   wire        fifo_deq_en;
   wire        fifo_deq_rdy;

   assign     dsp_rst_n = !dsp_rst;
   assign     ser_tx_clk = dsp_clk;
   
   SizedFIFO #(.p1width(18),
               .p2depth(FIFOSIZE),
               .p3cntr_width(CNTR_WIDTH)) fifo_buf
     (.CLK(dsp_clk),
      .RST_N(dsp_rst_n),
      .CLR(),
      .D_IN({tx_kmsb_i,tx_klsb_i,tx_dat_i}),
      .ENQ(tx_en),
      .FULL_N(tx_rdy),
      .D_OUT(fifo_d_out),
      .DEQ(fifo_deq_en),
      .EMPTY_N(fifo_deq_rdy));   

   assign      fifo_deq_en   = (!send_comma && fifo_deq_rdy);
   assign      ser_tkmsb_int = (send_comma || !fifo_deq_rdy) ? 1'b1 : fifo_d_out[17];
   assign      ser_tklsb_int = (send_comma || !fifo_deq_rdy) ? 1'b1 : fifo_d_out[16];
   assign      ser_t_int     = (send_comma || !fifo_deq_rdy) ? 16'b0011110000111100 : fifo_d_out[15:0];

   always @(posedge ser_tx_clk)
     begin
	ser_tklsb <= ser_tklsb_int;
	ser_tkmsb <= ser_tkmsb_int;
        ser_t     <= ser_t_int;
        if (switch_countdown == 0)
          begin
             send_comma <= !send_comma;
             switch_countdown <= (send_comma == 0) ? 15 : 65535; 
          end
        else
          begin
             switch_countdown <= switch_countdown - 1;
          end        
     end



endmodule // u2_rev2
