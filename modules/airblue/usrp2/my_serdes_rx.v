`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module u2_rev3
  (   
   // Misc, debug
   output [5:0] leds,

   // Clocks
   input clk_fpga_p,  // Diff
   input clk_fpga_n,  // Diff

   // SERDES
   output ser_enable,
   output ser_prbsen,
   output ser_loopen,
   output ser_rx_en,
   
   output ser_tx_clk,
   output reg [15:0] ser_t,
   output reg ser_tklsb,
   output reg ser_tkmsb,

   input ser_rx_clk,
   input [15:0] ser_r,
   input ser_rklsb,
   input ser_rkmsb
      );

   // FPGA-specific pins connections
   wire       clk_fpga;
   wire       clk_fpga_unbuf;

   IBUFGDS clk_fpga_pin (.O(clk_fpga_unbuf),.I(clk_fpga_p),.IB(clk_fpga_n));
   BUFG clk_fpga_BUF (.O(clk_fpga),.I(clk_fpga_unbuf));  

   defparam 	clk_fpga_pin.IOSTANDARD = "LVPECL_25";

   reg  [15:0] ser_r_int;
   reg 	       ser_rklsb_int, ser_rkmsb_int;
   reg [15:0]  switch_countdown; 
   wire        ser_tklsb_int, ser_tkmsb_int;
   wire [15:0] ser_t_int;
   wire [15:0] comma_count, data_count;
   reg         send_comma;
   wire        tx_prbs_en_seed;
   wire        tx_prbs_en_next;
   wire [15:0] tx_prbs_seed_l;
   wire        user_tx_reset_n_i;
   wire [15:0] tx_prbs_data;
   reg  [1:0]  last_rxcharisk0_i;
   wire [1:0]  rxcharisk0_i;
   wire        rx_prbs_check;
   wire        rx_prbs_check_start;
   wire        rx_prbs_en_seed;
   wire        rx_prbs_en_next;
   wire [15:0] rx_prbs_seed_1;
   wire [15:0] rx_prbs_data;
   wire [15:0] rx_odd_aligned_data;
   wire [15:0] rx_aligned_data;
   reg  [15:0] last_rx_aligned_data;
   reg         rx_odd_aligned;
   reg         rx_check;
   wire        user_rx_reset_n_i;
   reg  [39:0] rx_count;
   reg  [39:0] rx_error;
   wire [35:0] control0;
   wire [35:0] control1;
   wire [35:0] control2;
   wire [35:0] control3;
   wire [35:0] control4;
   wire [39:0] trig0;
   wire [39:0] trig1;
   wire [39:0] trig2;
   wire [31:0] async_out0;
   wire [31:0] async_out1;
   reg  [15:0] last_rxdata0_i;
   wire [15:0] rxdata0_i;
   wire        tx_data_is_prbs;

   
   wire       ser_rx_clk_buf;
   BUFG ser_rx_clk_BUF (.O(ser_rx_clk_buf),.I(ser_rx_clk));
   always @(posedge ser_rx_clk_buf)
     begin
        ser_r_int <= ser_r;
	ser_rklsb_int <= ser_rklsb;
	ser_rkmsb_int <= ser_rkmsb;
     end

   assign leds       = 6'b101001;
   
   assign ser_enable = 1'b1;
   assign ser_prbsen = 1'b0;
   assign ser_loopen = 1'b0;
   assign ser_rx_en  = 1'b1;
   assign rxdata0_i = ser_r_int;
   assign rxcharisk0_i = {ser_rkmsb_int, ser_rklsb_int}; 

   assign ser_tx_clk = clk_fpga;   
   
   assign   tx_prbs_en_seed = !tx_data_is_prbs;
   assign   tx_prbs_en_next = 1'b1;
   assign   tx_prbs_seed_l = 16'ha739;
   
    mkPRBS tx_prbs
     (.CLK(ser_tx_clk),
      .RST_N(user_tx_reset_n_i),
      .seed_1(tx_prbs_seed_l),
      .EN_seed(tx_prbs_en_seed),
      .value(tx_prbs_data),
      .EN_next(tx_prbs_en_next));

   

   assign   rx_prbs_check_start = ((last_rxcharisk0_i == 2'b11) && (rxcharisk0_i == 2'b00)) || (last_rxcharisk0_i == 2'b01);
   assign   rx_prbs_en_seed = rx_prbs_check_start;
   assign   rx_prbs_en_next = rx_check; // en_next whenever it is not en_seed
   assign   rx_prbs_seed_1 = rx_aligned_data; // the seed is first rx_data
   assign   rx_odd_aligned_data = {rxdata0_i[7:0] ,last_rxdata0_i[15:8]};
   assign   rx_aligned_data = (rx_odd_aligned == 1'b1) ? rx_odd_aligned_data : rxdata0_i;

   mkPRBS rx_prbs
     (.CLK(ser_rx_clk_buf),
      .RST_N(user_rx_reset_n_i),
      .seed_1(rx_prbs_seed_1),
      .EN_seed(rx_prbs_en_seed),
      .value(rx_prbs_data),
      .EN_next(rx_prbs_en_next));

   always @(posedge ser_rx_clk_buf)
     begin
        if (!user_rx_reset_n_i)
          begin
             rx_check <= 1'b0; // idle
             rx_count <= 0;
             rx_error <= 0;
             rx_odd_aligned <= 0;
          end
        else
          begin
             last_rxcharisk0_i <= rxcharisk0_i;
             last_rxdata0_i <= rxdata0_i;
             last_rx_aligned_data <= rx_aligned_data;
             rx_check <= !rxcharisk0_i[0];
             if (rxcharisk0_i == 2'b11)
               begin
                  rx_odd_aligned <= 1'b0;
               end
             else
               if (rxcharisk0_i == 2'b01)
                 begin
                    rx_odd_aligned <= 1'b1;
                 end
             if (rx_prbs_check == 1'b0)
               begin
                  rx_count <= 0;
                  rx_error <= 0;
               end
             else
               begin
                  if (rx_check == 1'b1)
                    begin		
                       rx_count <= rx_count + 1;
                       if (last_rx_aligned_data != rx_prbs_data)
                         begin
                            rx_error <= rx_error + 1;
                         end
                    end
               end // else: !if(rx_prbs_check == 1'b0)
          end // else: !if(!usr_rx_reset_n_i)
     end

   always @(posedge ser_tx_clk)
     begin
        if (send_comma)
          begin
             ser_tklsb <= 1'b1;
             ser_tkmsb <= 1'b1;
             ser_t     <= 16'b0011110000111100;
          end
        else
          begin
	     ser_tklsb <= ser_tklsb_int;
	     ser_tkmsb <= ser_tkmsb_int;
             ser_t     <= ser_t_int;
          end        
        if (switch_countdown == 0)
          begin
             send_comma <= !send_comma;
             switch_countdown <= (send_comma == 0) ? comma_count : data_count; 
          end
        else
          begin
             switch_countdown <= switch_countdown - 1;
          end        
     end

   assign      trig0 = {4'd0,last_rx_aligned_data[15:0],rx_odd_aligned,rx_prbs_check_start,ser_rkmsb_int,ser_rklsb_int,ser_r_int[15:0]};
   assign      trig1 = rx_error;
   assign      trig2 = rx_count;
   assign      comma_count = async_out0[15:0]; // how long to send comma?
   assign      data_count  = async_out0[31:16]; // how long to send data?
   assign      user_tx_reset_n_i = !async_out1[21];
   assign      user_rx_reset_n_i = !async_out1[20];
   assign      rx_prbs_check = async_out1[19]; // start rx prbs check when 1 (reset counter if 0)
   assign      tx_data_is_prbs = async_out1[18]; // tx prbs data?
   assign      ser_tkmsb_int = (tx_data_is_prbs == 1'b1) ? 1'b0 : async_out1[17];
   assign      ser_tklsb_int = (tx_data_is_prbs == 1'b1) ? 1'b0 : async_out1[16];
   assign      ser_t_int     = (tx_data_is_prbs == 1'b1) ? tx_prbs_data : async_out1[15:0];

   icon icon1 (.CONTROL0(control0), .CONTROL1(control1), .CONTROL2(control2), .CONTROL3(control3), .CONTROL4(control4)); 
   ila ila1 (.CONTROL(control0), .CLK(ser_rx_clk_buf), .TRIG0(trig0));
   ila ila2 (.CONTROL(control1), .CLK(ser_rx_clk_buf), .TRIG0(trig1));
   ila ila3 (.CONTROL(control2), .CLK(ser_rx_clk_buf), .TRIG0(trig2));   
   vio vio1 (.CONTROL(control3), .ASYNC_OUT(async_out0));
   vio vio2 (.CONTROL(control4), .ASYNC_OUT(async_out1));

//    wire        fifo_not_full;
//    wire        fifo_not_empty;
//    wire        rst;
   
//    assign enq_en = fifo_not_full; // always tries to enq if possible
//    assign deq_en = fifo_not_empty; // always tries to deq if possible
//    assign rst = 1'b1;
   
//    SyncFIFO #(.dataWidth(18), .depth(512), .indxWidth(9)) ser_rx_fifo
//      (.sCLK(ser_rx_clk_buf),
//       .sRST_N(rst),
//       .dCLK(ser_tx_clk),
//       .sENQ(enq_en),
//       .sD_IN({ser_rkmsb_int,ser_rklsb_int,ser_r_int}),
//       .sFULL_N(fifo_not_full),
//       .dDEQ(deq_en),
//       .dD_OUT({ser_tkmsb_int,ser_tklsb_int,ser_t_int}),
//       .dEMPTY_N(fifo_not_empty)
//       );


endmodule // u2_rev2
