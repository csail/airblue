import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;
import CBus::*;

// import MACDataTypes::*;
// import ProtocolParameters::*;
// import RXController::*;
// import TXController::*;
// import MACPhyParameters::*;

// import FPGAParameters::*;
// import CBusUtils::*;

// local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/c_bus_utils.bsh"

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
   
   //aborting transmissions
   interface Put#(Bit#(0))  abortAck;
   interface Get#(Bit#(0))  abortReq; 

endinterface
   

//(*synthesize*)
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkSHIM (SHIM);
   
   
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACSHIMAbort0 = CRAddr{a: fromInteger(valueof(AddrMACSHIMAbort0)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACSHIMAbort1 = CRAddr{a: fromInteger(valueof(AddrMACSHIMAbort1)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACSHIMCycle  = CRAddr{a: fromInteger(valueof(AddrMACSHIMCycle)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRate          = CRAddr{a: fromInteger(valueof(AddrRate)) , o: 0};
   
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

   //true from receiving hdr to starting own tx
   Reg#(Bool)     startSecondary <- mkReg(False); 
   
   //true from receving hdr to notifying old mac
   Reg#(Bool)     startSecondaryNotified <- mkReg(False);
   
   //true from receiving hdr to sending abort req
   Reg#(Bool)     startAbort <- mkReg(False);
   
   //false from receiving hdr to receiving abort ack
   Reg#(Bool)     doneAbort <- mkReg(True);

   // calculate how the receiver may abort
   Reg#(Bit#(32))  abort0 <-  mkCBRegR(addrMACSHIMAbort0,0);
   Reg#(Bit#(32))  abort1 <-  mkCBRegR(addrMACSHIMAbort1,0);
   Reg#(Bit#(32))  shim_cycle  <-  mkCBRegR(addrMACSHIMCycle,500);
   Reg#(Rate)      ext_rate <- mkCBRegRW(addrRate,R0); 
   
   FIFO#(Bit#(0))  abortReqFIFO <- mkFIFO;
   FIFO#(Bit#(0))  abortAckFIFO <- mkFIFO;  
   
   rule incrCounter(True);
      shim_cycle <= shim_cycle + 1;
   endrule
   
   rule doStartAbort(startAbort);
      abortReqFIFO.enq(?);
      startAbort <= False;
      $display($time, " MACSHIM %d starting abort", my_mac_sa);
   endrule
   
   rule deqAbortAck(True);
      abortAckFIFO.deq;
      doneAbort <= True;
      $display($time, " MACSHIM %d done abort", my_mac_sa);
   endrule
   
   interface Put mac_sa;
      method Action put(Bit#(48) a);
	 my_mac_sa <= a;
      endmethod
   endinterface
   	 
   // SHIM <-> Phy
   interface Get phy_txstart;  
      method ActionValue#(TXVector) get() if(txStartFull);
	 $display($time, " MACSHIM %d TX Start from phy", my_mac_sa);
	 txStartFull <= False;
	 return txvector;
      endmethod
   endinterface
   
   interface Get phy_txdata;  
      method ActionValue#(PhyData) get() if(txDataFull);
	 $display($time," MACSHIMVERBOSE %d TX Data from phy", my_mac_sa);
	 txDataFull <= False;
	 if(startSecondary)
	    begin
	       $display($time," MACSHIM %d reset start secondary", my_mac_sa);
	       startSecondary <= False; //reset start secondary
	       startSecondaryNotified <= False; 
	    end
	 return txdata;
      endmethod
   endinterface
   
   
   interface Put phy_rxstart;
      method Action put(RXVector vector) if(!rxStartFull);
	 if(!vector.is_trailer)
	    begin
	       $display($time," MACSHIM %d RX Start Header from phy: %d to %d, len %d @ %d", 
		  my_mac_sa, vector.header.src_addr, vector.header.dst_addr, 
		  vector.header.length,shim_cycle);
	       
	       //xxx temporary map used: allow 22 -> 29 and 36 -> 15 simultaneously, rate R0
	       
	       if(((vector.header.src_addr==22 && my_mac_sa==36)
		   || (vector.header.src_addr==36 && my_mac_sa==22))
		  && vector.header.dst_addr != my_mac_sa[7:0])	
		  //code to initiate concurrent transmissions
		  //xxx replace with hash table in future	  
		  begin
                     abort0 <= abort0 + 1;
//		     startSecondary <= True;
		     startAbort <= True;
		     doneAbort <= False;
		     $display($time," MACSHIM %d must start secondary tx. abort0: %d", my_mac_sa, abort0);
		  
		  end
	       else if(((vector.header.src_addr==22 && my_mac_sa==15)
		   || (vector.header.src_addr==36 && my_mac_sa==29)) 
		  && vector.header.dst_addr != my_mac_sa[7:0])
		  //xxx ugly hack: I might get a new packet, so abort this transmission
		  //in future, either PHY should be capable of resyncing on a new preamble
		  //or, header must designate a secondary tx receiver and that guy alone should abort
		  begin
                     abort1 <= abort1 + 1;
		     startAbort <= True;
		     doneAbort <= False;
		     $display($time," MACSHIM %d ignoring reception. abort1: %d", my_mac_sa,abort1);
		  end
	       else //receive normally
		  begin
		     rxvector <= vector;
		     rxStartFull <= True;
		  end
	       
	    end
	 else
	    begin
	       $display($time," MACSHIM %d RX Start Trailer from phy: %d", 
		  my_mac_sa, vector.header.length);
	       //do nothing on trailer for now
	    end
      
      endmethod
   endinterface
   
   interface Put phy_rxdata;
      method Action put(PhyData data) if(!rxDataFull);
	 
	 if(doneAbort)
	    begin
	       //check for corner case
	       if(startSecondary) 
		  begin
		     $display($time, " MACSHIM %d why rx data if start secondary and abort done?",
			      my_mac_sa);
		     $finish;  
		  end
               //normal behavior: just pass data to old mac
	       $display($time," MACSHIMVERBOSE %d RX Data from phy", my_mac_sa);
	       rxdata <= data;
	       rxDataFull <= True;
	    end
	 else
	    begin //data coming in before while aborting, ignore
	       $display($time," MACSHIMVERBOSE %d ignoring RX Data from phy", my_mac_sa);
	    end
      endmethod
   endinterface
   
   
   //SHIM <-> Old MAC
   
   interface Get mac_rxstart;  
      method ActionValue#(BasicRXVector) get() if(rxStartFull);
	 $display($time," MACSHIM %d RX Start to old mac", my_mac_sa);
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
	 $display($time," MACSHIMVERBOSE %d RX Data to old mac", my_mac_sa);
	 rxDataFull <= False;
	 return rxdata;
      endmethod
   endinterface
   
   
   interface Put mac_txstart;
      method Action put(BasicTXVector vector) if(!txStartFull);
	 $display($time," MACSHIM %d TX Start from old mac: from %d to %d, len %d", 
	    my_mac_sa, vector.src_addr, vector.dst_addr, vector.length);
	 //trasnlate between old and new formats
	 TXVector txv;
	 
	 //set rate by looking up hash table and conc transmissions in future 
         // xxx hardcoded for now
//	 txv.header.rate = R0;
	 txv.header.rate = ext_rate;
         
	 txv.header.power = vector.power;
	 txv.header.length = vector.length;
         // length = 14 is assumed to be ACK in this case
	 if(vector.length>14) txv.header.has_trailer = False;
	 else  txv.header.has_trailer = False;
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
	 $display($time," MACSHIMVERBOSE %d TX Data from old mac", my_mac_sa);
	 txdata <= data;
	 txDataFull <= True;
      endmethod
   endinterface
   
   //CCA
   interface Put phy_cca_ind_phy;
      method Action put(PhyCcaStatus_T s);
	 
	 if(startSecondary && doneAbort) //try starting conc
	    begin
	       if(!startSecondaryNotified)
		  begin
		     
		     $display($time," MACSHIM %d sending CONC signal", my_mac_sa);
		     phy_cca_status <= CONC;
		     startSecondaryNotified <= True;
		  end
	       else //notification done, just send idle
		  begin
		     phy_cca_status <= IDLE;
		     $display($time," MACSHIM %d sending false IDLE signal", my_mac_sa);
		  end
	    end
	 else
	    phy_cca_status <= s;
      endmethod
   endinterface
   
   interface Get phy_cca_ind_mac;
      method ActionValue#(PhyCcaStatus_T) get();
	 return phy_cca_status;
      endmethod
   endinterface
   
   interface abortReq = fifoToGet(abortReqFIFO);
   interface abortAck = fifoToPut(abortAckFIFO);    

endmodule

