import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import MACDataTypes::*;
import ProtocolParameters::*;
import RXController::*;
import TXController::*;
import MACPhyParameters::*;


interface SHIM;
   // SHIM <-> Phy
   interface Get#(TXVector)      phy_txstart;  
   interface Put#(RXVector)      phy_rxstart;   
   interface Get#(PhyData)       phy_txdata;     
   interface Put#(PhyData)       phy_rxdata;   

   // OLD MAC <-> SHIM
   interface Put#(BasicTXVector)      mac_txstart;  
   interface Get#(BasicRXVector)      mac_rxstart;   
   interface Put#(PhyData)       mac_txdata;     
   interface Get#(PhyData)       mac_rxdata;   
   
   //CCA
   interface Put#(PhyCcaStatus_T)     phy_cca_ind_phy;  // carrier sense indication from PHY to MAC
   interface Get#(PhyCcaStatus_T) phy_cca_ind_mac;   
      
   interface Put#(Bit#(48))           mac_sa;  
endinterface
   

(*synthesize*)
module mkSHIM (SHIM);

   Reg#(RXVector) rxvector <- mkRegU;  
   Reg#(TXVector) txvector <- mkRegU;  
   Reg#(PhyData) rxdata <- mkRegU;  
   Reg#(PhyData) txdata <- mkRegU; 
   Reg#(PhyCcaStatus_T)      phy_cca_status <- mkReg(IDLE); 
   
   Reg#(Bool)     rxStartFull <- mkReg(False); 
   Reg#(Bool)     rxDataFull <- mkReg(False); 
   Reg#(Bool)     txStartFull <- mkReg(False);
   Reg#(Bool)     txDataFull <- mkReg(False);

   Reg#(Bit#(48))            my_mac_sa <- mkReg(0); // SA, my address
   
   interface Put mac_sa;
      method Action put(Bit#(48) a);
	 my_mac_sa <= a;
      endmethod
   endinterface
   	 
   // SHIM <-> Phy
   interface Get phy_txstart;  
      method ActionValue#(TXVector) get() if(txStartFull);
	 $display("MACSHIM TX Start from phy");
	 txStartFull <= False;
	 return txvector;
      endmethod
   endinterface
   
   interface Get phy_txdata;  
      method ActionValue#(PhyData) get() if(txDataFull);
	 $display("MACSHIMVERBOSE TX Data from phy");
	 txDataFull <= False;
	 return txdata;
      endmethod
   endinterface
   
   
   interface Put phy_rxstart;
      method Action put(RXVector vector) if(!rxStartFull);
	 if(!vector.is_trailer)
	    begin
	       $display("MACSHIM RX Start Header from phy: %d to %d, len %d", 
		  vector.header.src_addr, vector.header.dst_addr, vector.header.length);
	       rxvector <= vector;
	       rxStartFull <= True;
	    end
	 else
	    begin
	       $display("MACSHIM RX Start Trailer from phy: %d", vector.header.length);
	       //do nothing on trailer for now
	    end
	 
      endmethod
   endinterface
   
   interface Put phy_rxdata;
      method Action put(PhyData data) if(!rxDataFull);
	 $display("MACSHIMVERBOSE RX Data from phy");
	 rxdata <= data;
	 rxDataFull <= True;
      endmethod
   endinterface
     
   
   //SHIM <-> Old MAC
   
   interface Get mac_rxstart;  
      method ActionValue#(BasicRXVector) get() if(rxStartFull);
	 $display("MACSHIM RX Start to old mac");
	 rxStartFull <= False;
	 BasicRXVector brxvector;
	 //translate between old and new formats
	 brxvector.rate = rxvector.header.rate;
	 brxvector.length = rxvector.header.length;
	 return brxvector;
      endmethod
   endinterface
   
   interface Get mac_rxdata;  
      method ActionValue#(PhyData) get() if(rxDataFull);
	 $display("MACSHIMVERBOSE RX Data to old mac");
	 rxDataFull <= False;
	 return rxdata;
      endmethod
   endinterface
   
   
   interface Put mac_txstart;
      method Action put(BasicTXVector vector) if(!txStartFull);
	 $display("MACSHIM TX Start from old mac: from %d to %d, len %d", 
	    vector.src_addr, vector.dst_addr, vector.length);
	 //trasnlate between old and new formats
	 TXVector txv;
	 txv.header.rate = vector.rate;
	 txv.header.power = vector.power;
	 txv.header.length = vector.length;
	 txv.header.has_trailer = False;
	 txv.header.src_addr = vector.src_addr;
	 txv.header.dst_addr = vector.dst_addr;
	 txv.header.uid = ?;
	 txv.pre_data = tagged Valid 0;
	 txv.post_data = tagged Valid 0;
	 txvector <= txv;
	 txStartFull <= True;
	 
      endmethod
   endinterface
   
   interface Put mac_txdata;
      method Action put(PhyData data) if(!txDataFull);
	 $display("MACSHIMVERBOSE TX Data from old mac");
	 txdata <= data;
	 txDataFull <= True;
      endmethod
   endinterface
   
   //CCA
   interface Put phy_cca_ind_phy;
      method Action put(PhyCcaStatus_T s);
	 phy_cca_status <= s;
      endmethod
   endinterface
   
   interface Get phy_cca_ind_mac;
      method ActionValue#(PhyCcaStatus_T) get();
	 return phy_cca_status;
      endmethod
   endinterface
   
     
endmodule

