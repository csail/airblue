import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Connectable::*;

import MACDataTypes::*;
import Mac80211::*;
import Phy80211::*;


interface Sta_IFC#(numeric type sa) ;
   interface Put#(MacFrame_T)    sta_txframe;
   interface Get#(MacFrame_T)    sta_rxframe;
   interface Put#(PhySapData_T)  rf_rxdata;
   interface Get#(PhySapData_T)  rf_txdata;
endinterface

module mkSta80211(Sta_IFC#(sa));
   Mac_IFC#(sa)         wifiMac <- mkMac80211();
   Phy_IFC              wifiPhy <- mkPhy80211();
   
   
   mkConnection(wifiMac.phy_data_req,wifiPhy.phy_data_req);
   mkConnection(wifiMac.phy_data_ind,wifiPhy.phy_data_ind);
   mkConnection(wifiMac.phy_cca_ind,wifiPhy.phy_cca_ind);

  

   interface Put sta_txframe;
      method Action put(MacFrame_T x);
	 //$display("interface put sta_txframe");
	 wifiMac.llc_mac_tx_frame.put(x);
      endmethod
   endinterface
   
   interface Get sta_rxframe;
      method ActionValue#(MacFrame_T) get();
	 //$display("interface get sta_rxframe");
	 let x <- wifiMac.llc_mac_rx_frame.get();
	 return x;
      endmethod
   endinterface

   interface Put rf_rxdata;
      method Action put(PhySapData_T x);
	 //$display("interface put rf_rxdata");
	 wifiPhy.rf_phy_rxdata.put(x);
      endmethod
   endinterface
   
   interface Get rf_txdata;
      method ActionValue#(PhySapData_T) get();
	 //$display("interface get rf_txdata");
	 let x <- wifiPhy.rf_phy_txdata.get();
	 return x;
      endmethod
   endinterface

endmodule