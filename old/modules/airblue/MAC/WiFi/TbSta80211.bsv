import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Connectable::*;

import MACDataTypes::*;
import Sta80211::*;


module mkTbSta80211();
   Sta_IFC#('b01)            wifiSta <- mkSta80211();
   Sta_IFC#('b00)            wifiAp <- mkSta80211();

   Reg#(Bool)                add_tx_mac_data <- mkReg(True); // start TX
   Reg#(Bit#(3))             llc_pkts <- mkReg(2);
   Reg#(DataFrame_T)         sent_data <- mkReg(?);
   Reg#(CommonCtlFrame1_T)   sent_ctl <- mkReg(?);
   FIFOF#(MacFrame_T)        rxfrm <- mkSizedFIFOF(2);
   
   mkConnection(wifiSta.rf_rxdata,wifiAp.rf_txdata);
   mkConnection(wifiSta.rf_txdata,wifiAp.rf_rxdata);
//    wifiSta.mac_sa.put('b01);
//    wifiAp.mac_sa.put('b00);

   rule dummy_sta_llc_tx (add_tx_mac_data);
      DataFrame_T d1 = unpack('h0000);
      $display("dummy_sta_llc_tx");
      
      d1.hdr.frame_ctl.prot_ver = 1;
      d1.hdr.frame_ctl.pwr_mgt = 0;
      d1.hdr.frame_ctl.type_val = 2'b10; // 'b10 for data, 01 for control
      d1.hdr.frame_ctl.subtype_val = 4'b0000; // 'b0000 for data, 1101 for ACK
      d1.hdr.frame_ctl.to_ds = 1;
      d1.hdr.frame_ctl.from_ds = 0;
      d1.hdr.add1 = 'b00; // DA
      d1.hdr.add2 = 'b01; // SA
      if(llc_pkts > 1)
	 d1.hdr.frame_ctl.more_frag = 1;
      else d1.hdr.frame_ctl.more_frag = 0;
      wifiSta.sta_txframe.put(tagged Df d1);
      sent_data <= d1;
      add_tx_mac_data <= False;
   endrule
   
   rule dummy_sta_llc_rx;
      $display("dummy_sta_llc_rx");
      let x <- wifiSta.sta_rxframe.get();
      rxfrm.enq(x);
   endrule
   
   rule dummy_ap_llc_rx;
      $display("dummy_ap_llc_rx");
      let x <- wifiAp.sta_rxframe.get();
      rxfrm.enq(x);
   endrule
   rule dummy_llc_rx_proc;
      $display("dummy_llc_rx_proc");
      let x = rxfrm.first;
      case (x) matches
	 tagged Df .df : 
	    if(df == sent_data) $display("Data MATCH !!!!");
	 tagged Cf .cf:
	    case (cf) matches
	       tagged C1 .c1:
		  begin
		     $display(" Successful ACK");

		     if(llc_pkts>1) add_tx_mac_data <= True;
		     llc_pkts <= llc_pkts - 1;
		     
		  end
	    endcase
      endcase
      //$finish;
      rxfrm.deq;
   endrule
   
endmodule