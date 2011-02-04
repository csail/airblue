import FIFO::*;
import FIFOF::*;
import GetPut::*;

import MACDataTypes::*;
import Mac80211::*;
import Phy80211::*;


module mkTbMac80211();
   Reg#(Bool)             add_tx_mac_data <- mkReg(True); // start TX
   Reg#(Bool)             add_rx_phy_data <- mkReg(False); // start RX   
   Mac_IFC                wifiMac <- mkMac80211();
   
   Reg#(PhySapTXVector_T) txvector <- mkReg(?);
   Reg#(Bool)             txstart_conf <- mkReg(False);
   
   Reg#(PhySapData_T)     txdata <- mkReg(?);
   Reg#(Bool)             txdata_conf <- mkReg(False);
   Reg#(Bool)             txend_conf <- mkReg(False);
   
   Reg#(Bool)             rxstart_ind <- mkReg(False); 
   Reg#(Bool)             rxend_ind <- mkReg(False);
   Reg#(Bool)             rxdata_ind <- mkReg(False);
   Reg#(Bool)             cca_ind <- mkReg(False);
   Reg#(Bit#(3))          llc_pkts <- mkReg(3);
   
   FIFOF#(DataFrame_T)    mac_rxdata <- mkSizedFIFOF(1); // RX data from PHY

//   Reg#(Bool)             rx_data_ind <- mkReg(False);
   Reg#(Bit#(32))         rx_idx <- mkReg(fromInteger(valueOf(FrameSz))-1); 
   FIFO#(PhySapData_T)    phy_rxdata <- mkSizedFIFO(fromInteger(valueOf(FrameSz)));
   
//   rule dummy_llc_tx (add_tx_mac_data);
   rule dummy_llc_tx (llc_pkts > 0 && add_tx_mac_data);
      DataFrame_T d1;
      $display("dummy_llc_tx");
      
      d1.hdr.frame_ctl.prot_ver = 1;
      d1.hdr.frame_ctl.pwr_mgt = 0;
      d1.hdr.frame_ctl.type_val = 2'b10;
      d1.hdr.frame_ctl.subtype_val = 0;
      if(llc_pkts > 1)
	 d1.hdr.frame_ctl.more_frag = 1;
      else d1.hdr.frame_ctl.more_frag = 0;
      wifiMac.llc_mac_tx_data.put(d1);
      if(llc_pkts==1) add_tx_mac_data <= False;
      llc_pkts <= llc_pkts - 1;
   endrule
   
   rule dummy_phy_txstart_req;
      $display("dummy_phy_txstart_req");
      let x <- wifiMac.phy_txstart_req.get();
      txvector <= x;
      txstart_conf <= True;
      // do some phy TX parameter check
   endrule
   
   rule dummy_phy_txstart_conf (txstart_conf);
      $display("dummy_phy_txstart_conf");
      wifiMac.phy_txstart_conf.put(True);
      txstart_conf <= False;
   endrule
   
   rule dummy_phy_data_req;
      $display("dummy_phy_data_req");
      let x <- wifiMac.phy_data_req.get();
      txdata <= x;
      if(valueOf(ByPassDataConf)==0)
	 txdata_conf <= True; //GR: bypass this since it is taken care by fifo
      // do some phy TX parameter check
   endrule
   
   rule dummy_phy_data_conf (txdata_conf);
      $display("dummy_phy_start_conf");
      wifiMac.phy_data_conf.put(True);
      txdata_conf <= False;
   endrule
   
   rule dummy_phy_txend_req;
      $display("dummy_phy_txend_req");
      let x <- wifiMac.phy_txend_req.get();
      txend_conf <= True;
      // do some phy TX parameter check
   endrule
   
   rule dummy_phy_txend_conf (txend_conf);
      $display("dummy_phy_txend_conf");
      wifiMac.phy_txend_conf.put(True);
      txend_conf <= False;
   endrule
   
   rule dummy_phy_rx (add_rx_phy_data);
      DataFrame_T d1 = unpack('h0000);
      $display("dummy_phy_rx");
      
      d1.hdr.frame_ctl.subtype_val = 4'b0000;
      d1.hdr.frame_ctl.type_val = 2'b10;
      d1.hdr.frame_ctl.prot_ver = 1;
      d1.hdr.frame_ctl.pwr_mgt = 1;
      mac_rxdata.enq(d1);
      add_rx_phy_data <= False;
      rxstart_ind <= True;
   endrule
   
   rule dummy_phy_rxdata_ind (rxdata_ind);
      $display("dummy_phy_rxdata_ind");
      let rxdata = mac_rxdata.first;

      PhySapData_T rx_byte = 0;
      Bit#(FrameSz) mf = pack(rxdata);
      
      rx_byte = mf[rx_idx:rx_idx-7];
      if(rx_idx == 7)
	 begin
	    rxdata_ind <= False;
	    mac_rxdata.deq;
	    rxend_ind <= True;
	 end
      else rx_idx <= rx_idx - 8;
      
      wifiMac.phy_data_ind.put(rx_byte);
//      phy_rxdata.enq(rx_byte);
   endrule      

   
   rule dummy_phy_rxstart_ind (rxstart_ind);
      $display("dummy_phy_rxstart_ind");
      PhySapRXVector_T v1;
      v1.rate = R0;
      v1.length = fromInteger(valueOf(FrameSzBy)); // bytes 
      v1.service = 0;
      v1.power = 0;

      wifiMac.phy_rxstart_ind.put(v1);
      rxstart_ind <= False;
      rxdata_ind <= True; // send data to mac
   endrule

   rule dummy_phy_rxend_ind (rxend_ind);
      $display("dummy_phy_rxend_ind");
      RXERROR_T v1;
      v1 = NoError;

      wifiMac.phy_rxend_ind.put(v1);
      rxend_ind <= False;
   endrule
   
   rule dummy_phy_cca_ind (cca_ind);
      $display("dummy_phy_cca_ind");
      
      PhyCcaStatus_T s = IDLE;
      
      wifiMac.phy_cca_ind.put(s);
      cca_ind <= False;
   endrule

endmodule

