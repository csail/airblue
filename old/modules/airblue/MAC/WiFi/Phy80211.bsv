import FIFO::*;
import FIFOF::*;
import GetPut::*;

import MACDataTypes::*;
import Mac80211::*;

interface Phy_IFC;
   interface Put#(PhySapData_T)       phy_data_req;     // MAC TX data to PHY
   interface Get#(PhySapData_T)       phy_data_ind;     // RX data from PHY to MAC
   interface Get#(PhyCcaStatus_T)     phy_cca_ind;      // carrier sense indication from PHY to MAC      
   interface Put#(PhySapData_T)       rf_phy_rxdata;       // rf to phy rx
   interface Get#(PhySapData_T)       rf_phy_txdata;       // phy to rf tx

endinterface

module mkPhy80211(Phy_IFC);
   
   Reg#(PhySapTXVector_T) txvector <- mkReg(?);

   FIFO#(Bool)            cca_ind <- mkSizedFIFO(1);
    
   FIFO#(PhySapData_T)    phy_rxdata <- mkSizedFIFO(1);
   FIFO#(PhySapData_T)    phy_txdata <- mkSizedFIFO(1);
   
   
   interface Put phy_data_req;
      method Action put(PhySapData_T x);
	 //$display("dummy_phy_data_req");
	    phy_txdata.enq(x);
      endmethod
   endinterface
   
   
   interface Get phy_data_ind;
      method ActionValue#(PhySapData_T) get();
	 //$display("dummy_phy_data_ind");
	 let x = phy_rxdata.first;
	 phy_rxdata.deq;
	 return x;
      endmethod
   endinterface
   
   
   interface Get phy_cca_ind;
      method ActionValue#(PhyCcaStatus_T) get();
	 //$display("dummy_phy_cca_ind");
         let x = cca_ind.first;
	 PhyCcaStatus_T s = IDLE;
      
	 cca_ind.deq;
	 return s;
      endmethod
   endinterface
   
   
   interface Put rf_phy_rxdata;
      method Action put(PhySapData_T d);
	 //$display("interface put rf_phy_rxdata");
	 phy_rxdata.enq(d);
	// rxstart_ind.enq(True);
      endmethod
   endinterface

   interface Get rf_phy_txdata;
      method ActionValue#(PhySapData_T) get();
	 //$display("interface put rf_Phy_txdata");
	 let x = phy_txdata.first;
	 phy_txdata.deq;
	 return x;
      endmethod
   endinterface
   

endmodule

