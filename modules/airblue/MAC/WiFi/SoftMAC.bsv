import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import RWire::*;
import Connectable::*;
import CBus::*;

// local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_mac_crc.bsh"
`include "asim/provides/airblue_softhint_avg.bsh"
      
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkMAC(SoftMAC);
 
   let ackBuilder <- mkSoftRateAckBuilder;
   let hintAvg <- mkPacketBER;

   mkConnection(hintAvg.packet_ber, ackBuilder.ber);

   let macRXTXControl               <- mkMacRXTXControl(ackBuilder.ack);
   let macCRC                       <- mkMACCRC;
   //let macRate                      <- mkMACRateSoftware; 
   let shim <- mkSHIM;

   mkConnection(macRXTXControl.phy_txstart,macCRC.mac_txstart);
   mkConnection(macCRC.phy_txstart, shim.mac_txstart);
   mkConnection(macCRC.phy_txdata, shim.mac_txdata);
   mkConnection(interface Put;
                   method Action put(BasicRXVector x);
                      macCRC.phy_rxstart.put(x);
                      hintAvg.phy_rxstart.put(x);
                   endmethod
                endinterface,
                shim.mac_rxstart);
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

   interface phy_txstart = shim.phy_txstart;
   interface phy_txdata = shim.phy_txdata;     
   interface phy_txcomplete = macRXTXControl.phy_txcomplete; // PHY tells MAC tx is complete
   interface phy_rxdata = shim.phy_rxdata;     
   interface phy_cca_ind = shim.phy_cca_ind_phy;
   interface phy_rxstart = shim.phy_rxstart;
   interface phy_rxhints = hintAvg.phy_rxhints;

   interface mac_sw_txframe = macRXTXControl.mac_sw_txframe;
   interface mac_sw_rxframe = macRXTXControl.mac_sw_rxframe;
   interface mac_sw_txdata  = macRXTXControl.mac_sw_txdata;
   interface mac_sw_rxdata = macRXTXControl.mac_sw_rxdata;    
   interface mac_sw_txstatus = macRXTXControl.mac_sw_txstatus;  // tell upper level of success/failure   

   interface mac_abort = macCRC.mac_abort;
      
   interface abortAck = shim.abortAck;
   interface abortReq = shim.abortReq;
endmodule
