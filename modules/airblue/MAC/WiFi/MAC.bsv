import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import RWire::*;
import Connectable::*;
import CBus::*;

import FPGAParameters::*;
import ProtocolParameters::*;
import MACDataTypes::*;
import TXController::*;
import RXController::*;
import MACPhyParameters::*;

import MacRXTXControl::*;
import MACCRC::*;
//import MacRate::*;
import SHIM::*;
      
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkMAC(MAC);
  
   let macRXTXControl               <- mkMacRXTXControl;
   let macCRC                       <- mkMACCRC;
   //let macRate                      <- mkMACRateSoftware; 
   let shim <- mkSHIM;

   mkConnection(macRXTXControl.phy_txstart,macCRC.mac_txstart);
   mkConnection(macCRC.phy_txstart, shim.mac_txstart);
   mkConnection(macCRC.phy_txdata, shim.mac_txdata);
   mkConnection(macCRC.phy_rxstart, shim.mac_rxstart);
   mkConnection(macCRC.phy_rxdata, shim.mac_rxdata);
   
   mkConnection(macRXTXControl.phy_txdata,macCRC.mac_txdata);
   mkConnection(macCRC.mac_rxdata, macRXTXControl.phy_rxdata);
   mkConnection(macCRC.mac_rxstart, macRXTXControl.phy_rxstart);
   
   mkConnection(macRXTXControl.phy_cca_ind, shim.phy_cca_ind_mac);
   
   interface Put mac_sa;
      method Action put(Bit#(48) a);
	 macRXTXControl.mac_sa.put(a);
	 shim.mac_sa.put(a);
      endmethod
   endinterface
   
  //interface mac_sa = macRXTXControl.mac_sa; 
  interface phy_txstart = shim.phy_txstart;
  interface phy_txdata = shim.phy_txdata;     
  interface phy_txcomplete = macRXTXControl.phy_txcomplete; // PHY tells MAC tx is complete
  interface phy_rxdata = shim.phy_rxdata;     
  interface phy_cca_ind = shim.phy_cca_ind_phy;
  interface phy_rxstart = shim.phy_rxstart;          

  interface mac_sw_txframe = macRXTXControl.mac_sw_txframe;
  interface mac_sw_rxframe = macRXTXControl.mac_sw_rxframe;
  interface mac_sw_txdata  = macRXTXControl.mac_sw_txdata;
  interface mac_sw_rxdata = macRXTXControl.mac_sw_rxdata;    
  interface mac_sw_txstatus = macRXTXControl.mac_sw_txstatus;  // tell upper level of success/failure   

   interface mac_abort = macCRC.mac_abort;
      
   interface abortAck = shim.abortAck;
   interface abortReq = shim.abortReq;
endmodule
