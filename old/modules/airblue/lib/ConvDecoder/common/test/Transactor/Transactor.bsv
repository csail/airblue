//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

import Complex::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;
import RWire::*;
import StmtFSM::*;
import Vector::*;

// Local includes
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/fpga_components.bsh"

`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/rrr/client_stub_TRANSACTORRRR.bsh"

typedef enum {
   XACTOR_NULL = 0,
   XACTOR_BOTH = 1,
   XACTOR_RX_ONLY = 2
} XACTOR_TYPE deriving (Eq, Bits);

interface Transactor#(type tx_type, type rx_type);
   interface Put#(tx_type) tx_xactor_in;
   interface Get#(tx_type) tx_xactor_out;
   method Bool tx_stall;
   interface Put#(rx_type) rx_xactor_in;
   interface Get#(rx_type) rx_xactor_out;
   method Bool rx_stall;
endinterface   

module [CONNECTED_MODULE] mkTransactor (Transactor#(tx_type, rx_type))
   provisos (Bits#(tx_type,tx_sz),
             Bits#(rx_type,rx_sz));

   // host control
   ClientStub_TRANSACTORRRR client_stub <- mkClientStub_TRANSACTORRRR;

   // state elements
   FIFO#(tx_type) tx_fifo <- mkLFIFO();
   FIFO#(rx_type) rx_fifo <- mkLFIFO();
 
   // runtime parameters
   Reg#(XACTOR_TYPE) xactor_type     <- mkReg(XACTOR_NULL);
   Reg#(Bit#(32))    xactor_clk_ctrl <- mkReg(80);
   Reg#(Bool)        initialized <- mkReg(False);
   Reg#(Bool)        ranFSM <- mkReg(False);
   Reg#(Bit#(32))    counter <- mkReg(0);
   RWire#(Bit#(0))   reset_counter <- mkRWire();
   Reg#(Bool)        rx_first <- mkReg(False);

   Stmt initStmt = (seq
      client_stub.makeRequest_GetXactorType(0);
      action
         let resp <- client_stub.getResponse_GetXactorType();
         xactor_type <= unpack(truncate(resp));
      endaction
      client_stub.makeRequest_GetXactorClkCtrl(0);
      action
         let resp <- client_stub.getResponse_GetXactorClkCtrl();
         xactor_clk_ctrl <= resp;
         counter <= resp;
      endaction
      initialized <= True;
   endseq);

   FSM initFSM <- mkFSM(initStmt);
   
   let is_tx_stall = (xactor_type == XACTOR_BOTH && counter == 0);
   let is_rx_stall = (xactor_type != XACTOR_NULL && counter == 0);

   rule print_stall (True);
      if (`DEBUG_TRANSACTOR == 1)
         $display("Transactor tx_stall %d rx_stall %d",is_tx_stall,is_rx_stall);
   endrule
   
   rule init (!initialized && !ranFSM);
      initFSM.start();
      ranFSM <= True;
   endrule
   
   rule reset_count (initialized && isValid(reset_counter.wget()));
      counter <= xactor_clk_ctrl;
   endrule
   
   rule count_down (rx_first && initialized && xactor_type != XACTOR_NULL && counter > 0 && !isValid(reset_counter.wget())); 
      counter <= counter - 1;
   endrule
   
   interface Put tx_xactor_in  = fifoToPut(tx_fifo);
      
   interface Get tx_xactor_out = fifoToGet(tx_fifo);
   
   method Bool tx_stall;
      return is_tx_stall;
   endmethod
      
   interface Put rx_xactor_in;
      method Action put(rx_type data);
         reset_counter.wset(?);
         rx_fifo.enq(data);
         rx_first <= True;
      endmethod
   endinterface
   
   interface Get rx_xactor_out = fifoToGet(rx_fifo);
      
   method Bool rx_stall;
      return is_rx_stall;
   endmethod

endmodule
