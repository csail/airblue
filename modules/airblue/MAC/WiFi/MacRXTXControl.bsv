import FIFO::*;
import FIFOF::*;
import GetPut::*;
import RWire::*;
import LFSR::*;
import Vector::*;
import CBus::*;
import FixedPoint::*;

import Register::*;
import CBusUtils::*;

import FPGAParameters::*;
import ProtocolParameters::*;
import MACDataTypes::*;
import TXController::*;
import RXController::*;
import MACPhyParameters::*;

// local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/register_library.bsh"

function data_t funcXor(data_t a, data_t b)
   provisos(Bitwise#(data_t));
     return a^b;
endfunction

function Bool isControlFrame(MacSWFrame frm);
   if (frm.frame matches tagged Cf .*)
      return True;
   else
      return False;
endfunction

function Bool isManagementFrame(MacSWFrame frm);
   if (frm.frame matches tagged Mf .*)
      return True;
   else
      return False;
endfunction

function Bool isDataFrame(MacSWFrame frm);
   if (frm.frame matches tagged Df .*)
      return True;
   else
      return False;
endfunction

typedef enum {
  Success,
  Failure,
  Defer
} CWAction deriving (Bits,Eq);


// The main service of this MAC is to add on CRC and to provide ACKs.
module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkMacRXTXControl(BasicMAC);

   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACBkfTmr   = CRAddr{a: fromInteger(valueof(AddrMACBkfTmr)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACBkfSlots = CRAddr{a: fromInteger(valueof(AddrMACBkfSlots)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACIfsTmr   = CRAddr{a: fromInteger(valueof(AddrMACIfsTmr)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACAckTmr   = CRAddr{a: fromInteger(valueof(AddrMACAckTmr)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACSIFS     = CRAddr{a: fromInteger(valueof(AddrMACSIFS)) , o: 0};
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACOnlyTXSecondary = CRAddr{a: fromInteger(valueof(AddrMACOnlyTXSecondary)) , o: 0};
   
   Reg#(Bit#(32))            sifsTime <- mkCBRegRW(addrMACSIFS,fromInteger(valueOf(SIFSTime))); 
   Reg#(Bool)                only_tx_secondary <- mkCBRegRW(addrMACOnlyTXSecondary,False); 
   Reg#(Bool)                secondary_ready <- mkReg(False);
   
   Reg#(Bit#(8))             nav <- mkReg(0);
   
   Bit#(32)                  slotTime = fromInteger(valueOf(SlotTime)); 
//   Bit#(32)                  sifsTime = fromInteger(valueOf(SIFSTime));
   Bit#(32)                  difsTime = sifsTime + 2*slotTime;
   Bit#(32)                  eifsTime = sifsTime + difsTime; // + ACKTxTime
   Bit#(32)                  phyRxStDly = fromInteger(valueOf(PhyRxStartDelay)); 
   Bit#(32)                  ackTimeout = slotTime + sifsTime + phyRxStDly;
   
   Reg#(Bit#(32))            ctr0 <- mkReg(0);
   Reg#(Bit#(32))            ctr1 <- mkReg(0);
   FIFOF#(MacSWFrame)        mac_txfrm <- mkSizedFIFOF(1); // TX frame from LLC
   FIFOF#(MacSWFrame)        txfrm <- mkSizedFIFOF(1); //bypass for acks
   FIFOF#(MacSWFrame)        ackfrm <- mkSizedFIFOF(1); //bypass for acks
   FIFOF#(MacSWFrame)        mac_rxfrm <- mkSizedFIFOF(2); // RX frame to LLC
   FIFOF#(BasicTXVector)          phy_txvector <- mkSizedFIFOF(1);
   FIFOF#(BasicRXVector)          phy_rxvector <- mkSizedFIFOF(2);
   FIFOF#(PhySapData_T)      phy_txdataFIFO <- mkSizedFIFOF(1);
   FIFOF#(PhySapData_T)      phy_rxdataFIFO <- mkSizedFIFOF(2);
   FIFOF#(PhySapData_T)      llc_txdata <- mkFIFOF; 
   FIFOF#(PhySapData_T)      llc_rxdata <- mkFIFOF;// This may eventually be large for crc shootdown
   FIFO#(MACTxStatus)        llc_txstatus <- mkFIFO;
   FIFOF#(CWAction)          cwActionFIFO <- mkFIFOF;
   FIFOF#(Bit#(0))           txFIFO <- mkFIFOF; 
   Reg#(Bool)                tx_start_en <- mkReg(False);
   Reg#(CWIndex)             cwIndex <- mkReg(fromInteger(valueof(CWIndexMin)));

   Reg#(PhyPacketLength)      tx_idx <- mkReg(0); 
   Reg#(PhyPacketLength)      rx_idx <- mkReg(0);    
   Reg#(FrameCtl_T)           rx_fctl <- mkRegU;
  

   Reg#(Bit#(FrameSz))       mac_rxframe <- mkReg(0);
   Reg#(Bit#(FrameSz))       mac_txframe <- mkReg(0); // we should be able to get rid of this one. we don't need all the fifos
   Reg#(PhySapStatus_T)      phy_sap_rxstatus <- mkReg(Idle); // may want to merge with next
   Reg#(PhySapStatus_T)      phy_sap_txstatus <- mkReg(Idle);
   
   Reg#(Bool)                pre_frame_error <- mkReg(False);
   Reg#(Bool)                wait_for_ack <- mkReg(False);
   Reg#(Bit#(1))             more_frag <- mkReg(0);

   Reg#(Bit#(32))            ifs_tmr <-  mkCBRegR(addrMACIfsTmr,0);
   Reg#(Bit#(32))            ack_tmr <- mkCBRegR(addrMACAckTmr,0);
   Reg#(Bit#(32))            bkf_tmr <- mkCBRegR(addrMACBkfTmr,0);
   Reg#(Bit#(10))            bkf_slots <- mkCBRegR(addrMACBkfSlots,0);
   
   Reg#(PhyCcaStatus_T)      phy_cca_status <- mkReg(IDLE);

   PulseWire                 reset_tmr_cca <- mkPulseWire();
   PulseWire                 clk_tick <- mkPulseWire();
   FIFOF#(Bit#(0))           reset_tmr <- mkFIFOF;
   Reg#(Bit#(32))            stat <- mkReg(0);  


   // fix this at some point....
   LFSR#(Bit#(16)) backoffLFSR <- mkLFSR_16;


   // handle the MAC address functionality
   Reg#(Bit#(48))            my_mac_sa <- mkReg(0); // SA, my address
   // upon a write to the my_mac_sa, we want to scramble the backoff
   // register
 /*  function Action macUpdate(Bit#(48) a);
     action
       my_mac_sa <= a;
       Bit#(16) seed = fold(funcXor,unpack(a));
       backoffLFSR.seed((seed==0)?~0:seed);
       $display($time, " TB MAC Setting my MAC: %d seed: %d",a, (seed==0)?~0:seed);
     endaction
   endfunction

   mkCBusWideRegRW(valueof(MACAddrOffset),mkRegFromActions(my_mac_sa._read, macUpdate));*/

   Reg#(Bool)                startSecondary <- mkReg(False);

   rule statTick;
     stat <= stat + 1;
   endrule

   rule checkTxFIFOE (stat[15:0] == 0);
     $display($time, " TB MAC: addr %d", my_mac_sa);
     $display($time, " TB MAC: tx: %d rx: %d", phy_sap_txstatus, phy_sap_rxstatus );
     $display($time, " TB MAC: ifs_tmr: %d bkf_slots: %d bkf_tmr %d ack_tmr %d", ifs_tmr, bkf_slots, bkf_tmr, ack_tmr);
 
    if(!phy_txvector.notEmpty)
       begin
         $display($time, " TB MAC: phy tx vec empty");
       end
     else if(!phy_txvector.notFull)
       begin
         $display($time, " TB MAC: phy tx vec full");
       end
     else
       begin
         $display($time, " TB MAC: phy tx vec has data");
       end 

     if(!phy_rxvector.notEmpty)
       begin
         $display($time, " TB MAC: phy rx vec empty");
       end
     else if(!phy_rxvector.notFull)
       begin
         $display($time, " TB MAC: phy rx vec full");
       end
     else
       begin
         $display($time, " TB MAC: phy rx vec has data");
       end
 
     if(!mac_txfrm.notEmpty)
       begin
         $display($time, " TB MAC: mac tx vec empty");
       end
     else if(!mac_txfrm.notFull)
       begin
         $display($time, " TB MAC: mac tx vec full");
       end
     else
       begin
         $display($time, " TB MAC: mac tx vec has data");
       end

     if(!txFIFO.notEmpty)
       begin
         $display($time, " TB MAC: accepted tx token empty");
       end
     else if(!txFIFO.notFull)
       begin
         $display($time, " TB MAC: accepted tx token full");
       end
     else
       begin
         $display($time, " TB MAC: accepted tx token has data");
       end 

     if(!txfrm.notEmpty)
       begin
         $display($time, " TB MAC: accepted tx vec empty");
       end
     else if(!txfrm.notFull)
       begin
         $display($time, " TB MAC: accepted tx vec full");
       end
     else
       begin
         $display($time, " TB MAC: accepted tx vec has data");
       end 

    if(!ackfrm.notEmpty)
       begin
         $display($time, " TB MAC: ack vec empty");
       end
     else if(!ackfrm.notFull)
       begin
         $display($time, " TB MAC: ack vec full");
       end
     else
       begin
         $display($time, " TB MAC: ack vec has data");
       end 


     if(!mac_rxfrm.notEmpty)
       begin
         $display($time, " TB MAC: mac rx vec empty");
       end
     else if(!mac_rxfrm.notFull)
       begin
         $display($time, " TB MAC: mac rx vec full");
       end
     else
       begin
         $display($time, " TB MAC: mac rx vec has data");
       end
 



     if(!phy_txdataFIFO.notEmpty)
       begin
         $display($time, " TB MAC: phy tx data empty");
       end
     else if(!phy_txdataFIFO.notFull)
       begin
         $display($time, " TB MAC: phy tx data full");
       end
     else
       begin
         $display($time, " TB MAC: phy tx data has data");
       end
 

     if(!phy_rxdataFIFO.notEmpty)
       begin
         $display($time, " TB MAC: phy rx data empty");
       end
     else if(!phy_rxdataFIFO.notFull)
       begin
         $display($time, " TB MAC: phy rx data full");
       end
     else
       begin
         $display($time, " TB MAC: phy rx data has data");
       end
 


    if(!llc_rxdata.notEmpty)
       begin
         $display($time, " TB MAC: llc rx data empty");
       end
    else if(!llc_rxdata.notFull)
       begin
         $display($time, " TB MAC: llc rx data full");
       end
     else
       begin
         $display($time, " TB MAC: llc rx data has data");
       end
 


   if(!llc_txdata.notEmpty)
       begin
         $display($time, " TB MAC: llc tx data empty");
       end
   else if(!llc_txdata.notFull)
       begin
         $display($time, " TB MAC: llc tx data full");
       end
     else
       begin
         $display($time, " TB MAC:llc tx data has data");
       end
 
   endrule

   
   // this guard isn't quite right since we may need to wait eifsTime.
   // cwActionFIFO needs to be not empty here otherwise we may miss a defer event 
   rule mac_setup(phy_sap_txstatus==Idle && phy_sap_rxstatus == Idle && phy_cca_status==IDLE && ifs_tmr>=difsTime 
                  && bkf_slots == 0 && bkf_tmr==0 && !ackfrm.notEmpty && !wait_for_ack && !cwActionFIFO.notEmpty
                  && (!only_tx_secondary || secondary_ready));
      mac_txfrm.deq;
      phy_sap_txstatus <= TxStart;
      txfrm.enq(mac_txfrm.first);
      secondary_ready <= False;
      $display($time, " MAC %d TB CW at %d: issued a new tx packet", my_mac_sa, stat); 
   endrule

   // ack does not care about backoff. or rx status - we'll be receiving, but we must push out the new data or timeout
   // XXX return ifs_tmr dependence at some point - we still need sifs time, i guess.  Really should retime how ifs_tmr works
   rule mac_setupACK(phy_sap_txstatus==Idle && phy_cca_status==IDLE  && ifs_tmr >= sifsTime && ackfrm.notEmpty && !wait_for_ack);
     ackfrm.deq;
     phy_sap_txstatus <= TxStart;
     txfrm.enq(ackfrm.first);
     $display($time, " MAC %d TB CW at %d: issued a new ack packet", my_mac_sa, stat); 
   endrule


   // wanting to be idle here may kill me
   // Once we enqueue something here, we have to finish it.
   rule mac_txstartframe_req (phy_sap_txstatus==TxStart);
    
      BasicTXVector v1;
      v1.rate = R0;
      v1.service = 0;
      v1.power = 0;
      v1.length = ?; // we will always assign
      v1.src_addr = ?; 
      v1.dst_addr = ?;
      //v1.header.has_trailer = False;
      //v1.header.src_addr = ?;
      //v1.header.dst_addr = ?;
      //v1.header.uid = ?;
      //v1.pre_data = tagged Valid 0;
      //v1.post_data = tagged Valid 0;
      let txframe = txfrm.first;

      
      PhyPacketLength cidx = zeroExtend('b0);
      
    
      case (txframe.frame) matches
	 tagged Df .df : 
	    begin //data
	       $display($time, " MAC %2d: sending data from %d to %d",
			my_mac_sa, df.add2, df.add1);
	       more_frag <= df.frame_ctl.more_frag;
               v1.length = txframe.dataLength + fromInteger(valueof(DataFrameOctets)); 
	       v1.src_addr = df.add2[7:0];
	       v1.dst_addr = df.add1[7:0];
               mac_txframe <= zeroExtend(reverseBits(pack(df)));
	    end
	 tagged Mf .mf : 
	    begin //management
	       $display($time, " MAC %2d: sending mgmt",my_mac_sa);
               v1.length = txframe.dataLength + fromInteger(valueof(ManagementFrameOctets)); 
               mac_txframe <= zeroExtend(reverseBits(pack(mf)));
	    end
	 tagged Cf .cf : 
	    begin//control
	       $display($time, " MAC %2d: sending ctl",my_mac_sa);               
	       case (cf) matches
		  tagged C1 .c1 : 
		     begin
                        mac_txframe <= zeroExtend(reverseBits(pack(c1)));
			cidx = fromInteger(valueOf(FrameC1SzBy));
                        v1.length = fromInteger(valueof(CommonCtlFrame1Octets)); 
		     end
		  tagged C2 .c2 :
		     begin
                        mac_txframe <= zeroExtend(reverseBits(pack(c2)));
			v1.length = fromInteger(valueOf(CommonCtlFrame2Octets));
		     end
		  tagged Poll .po :
		     begin
		     end
		  tagged Bar .br :
		     begin
		     end
		  tagged Ba .ba :
		     begin
		     end
	       endcase
	    end
      endcase
      
      phy_txvector.enq(v1);
      phy_sap_txstatus <= DataReq;
      tx_idx <= v1.length;
      tx_start_en <= True;

      $display($time, " MAC TB %2d: mac_txstartfrm_req, frame length: %d payload length: %d",my_mac_sa, v1.length,txframe.dataLength );
   endrule

   
   rule mac_txframe_rl (tx_start_en && tx_idx > 0);
      //$display($time, " mac_txframe");
      let txframe = txfrm.first;
      Bit#(FrameSz) mf = 0;
      Bool need_ack = False;
      
      case (txframe.frame) matches
	 tagged Df .df : 
	    begin //data
	       mf = pack(df);
	       need_ack = True; // not necessarily
	    end
	 tagged Mf .mf : 
	    begin //management
	    end
	 tagged Cf .cf : 
	    begin//control
	       case (cf) matches
		  tagged C1 .c1 : 
		     begin
			mf = zeroExtend(pack(c1));
		     end
		  tagged C2 .c2 :
		     begin
			mf = zeroExtend(pack(c2));
		     end
		  tagged Poll .po :
		     begin
		     end
		  tagged Bar .br :
		     begin
		     end
		  tagged Ba .ba :
		     begin
		     end
	       endcase
	    end
      endcase				  
    
      $display($time, " MACVERBOSE: tx data[%d]: %h",tx_idx,mf);
      // send the header first... we should eventually be generating the crc here or in the next moduel.
      if(tx_idx > txfrm.first.dataLength)
	 begin
          $display($time, " MACVERBOSE: phy_txdata enq header: %h",reverseBits(mac_txframe[7:0]));
           mac_txframe <= mac_txframe >> 8;
           phy_txdataFIFO.enq(reverseBits(truncate(mac_txframe))); //Pull off the double reverse here.      
         end 
      else   
        begin
          $display($time, " MACVERBOSE: phy_txdata enq %h", llc_txdata.first);
          llc_txdata.deq;
          phy_txdataFIFO.enq(llc_txdata.first); 
        end
      tx_idx <= tx_idx - 1;
   endrule      
   
   rule mac_txframe_complete_CF (tx_start_en && tx_idx == 0 && isControlFrame(txfrm.first));
      $display($time, " TB MAC %2d: ENQ TXFIFO",my_mac_sa);
      tx_start_en <= False;
      txfrm.deq; //XXX really?
      txFIFO.enq(?);
      phy_sap_txstatus <= Idle;
   endrule
   
   // assume all Dataframe require ack
   rule mac_txframe_complete_DF (tx_start_en && tx_idx == 0 && isDataFrame(txfrm.first));
      $display($time, " TB MAC %2d: ENQ TXFIFO",my_mac_sa);
      tx_start_en <= False;
      txfrm.deq; //XXX really?
      txFIFO.enq(?);
      phy_sap_txstatus <= Idle;
      $display($time, " MAC TB: set wait for ack, timeout %d us",ackTimeout);
      ack_tmr <= ackTimeout;
      wait_for_ack <= True;
   endrule

   rule mac_txframe_complete_MF (tx_start_en && tx_idx == 0 && isManagementFrame(txfrm.first));
      $display($time, " TB MAC %2d: ENQ TXFIFO",my_mac_sa);
      tx_start_en <= False;
      txfrm.deq; //XXX really?
      txFIFO.enq(?);
      phy_sap_txstatus <= Idle;
      llc_txstatus.enq(Success);       
   endrule
   
   rule checkrxdata(!phy_rxdataFIFO.notEmpty && rx_idx != 0);
    $display($time, " MAC TB %d: cidx %d WARNING RX DATA EMPTY", my_mac_sa,rx_idx);
   endrule
   
   // process rxdata
   rule mac_rxdata_ind ;
      //$display($time, " mac_rxdata_ind");
      MacFrame_T mRxFrame = unpack(zeroExtend('b0));
      let rxdata = phy_rxdataFIFO.first;
      let mf = mac_rxframe;
      PhyPacketLength cidx = rx_idx + 1;
      Bool  recvDone = False;

      // probably don't want to do this all the time.
      // check rx_fctl for a value to determine header length in octets.	  
      // always take 2 
      if(cidx <= 2 || (rx_fctl.type_val == Management && cidx <= fromInteger(valueof(ManagementFrameOctets))) 
                   || (rx_fctl.type_val == Data && cidx <= fromInteger(valueof(DataFrameOctets)))
                   || (rx_fctl.type_val == Control))  
        begin
          $display($time, " MACVERBOSE TB %d: cidx %d getting frame", my_mac_sa,cidx);
          mf = mf << 8;
          mf = mf | zeroExtend(rxdata);
          mac_rxframe <= mf;
        end
      else 
        begin
          $display($time, " MACVERBOSE TB %d: post-frame data payload", my_mac_sa);
        end   

      if(cidx == 2) // need two bytes
	 begin
            ackfrm.clear; // we're getting a new packet. shoot down the old ack, it's no good to us now. Is this right?
	    // received FrameCtl
	    $display($time, " MAC TB %d: received fctl",my_mac_sa);
	    rx_fctl <= unpack(truncate(pack(mf)));
	 end
      else if(cidx > 2) // this probably needs to get put in another rule, in which we make a crc decision
	 begin
	    $display($time, " MACVERBOSE %d: rx_fctl %b", my_mac_sa,rx_fctl);
	    case(rx_fctl.type_val)
	       Management: begin // management
			  $display($time, " MAC TB %2d: received mgmt frame", my_mac_sa);
		       end
	       Control: begin  // control
                          $display($time, " MACVERBOSE TB: Control Frame");
			  case (cidx) 
			     fromInteger(valueOf(FrameC2SzBy)) : if(rx_fctl.subtype_val == 4'b1011)
								    begin	 // RTS
								       $display($time, " TB MAC %2d: received RTS", my_mac_sa);
 								       mRxFrame = tagged Cf tagged C2 unpack(truncate(mf));
								    end      
			     fromInteger(valueOf(FrameC1SzBy)) : if(rx_fctl.subtype_val == 4'b1100)
								    begin	 // CTS
								       $display($time, " TB MAC %2d: received CTS",my_mac_sa);
								       mRxFrame = tagged Cf tagged C2 unpack(truncate(mf));
								    end
								 else if(rx_fctl.subtype_val == 4'b1101)
								    begin	 // ACK

                                                                       // somewhere we should check the mac address.        
                                                                       // should probably cross check to ensure the ack is for this packet
								       mRxFrame = tagged Cf tagged C1 unpack(truncate(mf));
                                                                       if(mRxFrame.Cf.C1.ra == my_mac_sa && wait_for_ack)   
                                                                         begin 
                                                                            $display($time," MAC TB %2d: received ACK, leng: %d",my_mac_sa,mRxFrame.Cf.C1.dur);    
 								            wait_for_ack <= False;
                                                                            $display($time, " MAC issues success");
                                                                            llc_txstatus.enq(Success);
                                                                            cwActionFIFO.enq(Success);
                                                                            ack_tmr <= 0; // successful ack
                                                                            // XXX CW fifo here
                                                                          end
                                                                       else
                                                                         begin
                                                                           $display($time," MAC TB %2d: received ACK, leng: %d but did not accept. Waiting: %b MAC: %d",my_mac_sa,mRxFrame.Cf.C1.dur,wait_for_ack,mRxFrame.Cf.C1.ra);    
                                                                         end
								    end
                                                                  else
                                                                    begin
                                                                       $display($time, " MAC %2d: received Unknown Ctrl type: %b",my_mac_sa,rx_fctl.subtype_val);
                                                                    end      
			     default : begin
                                         $display($time, " TB MACVERBOSE %2d: Unknown Frame type",my_mac_sa);
				       end
			  endcase
		       end
	       Data: begin // data
                         $display($time, " MACVERBOSE TB: Data Frame");
			  case(rx_fctl.subtype_val)
			     4'b0000: begin
					 $display($time, " MACVERBOSE cidx: %d rxdata: data",cidx);
                                         mRxFrame = tagged Df unpack(truncate(mf));
					 if(cidx == fromInteger(valueof(DataFrameOctets)) && (mRxFrame.Df).add1 == my_mac_sa) 
					    begin
                                              $display($time, " TB MAC %2d: received data frame",my_mac_sa);					       
					      $display($time, " TB MAC %2d: sending back ACK",my_mac_sa);
                                              $display($time, " TB MAC %2d: enqueuing new frame",my_mac_sa);
                                              CommonCtlFrame1_T c1 = unpack(zeroExtend('h0));
                                              c1.frame_ctl.type_val = 2'b01; // 'b10 for data, 01 for control
                                              c1.frame_ctl.subtype_val = 4'b1101; // 'b0000 for data, 1101 for ACK
                                              c1.frame_ctl.to_ds = 0;
                                              c1.frame_ctl.from_ds = 0;
                                              c1.dur = zeroExtend(phy_rxvector.first.length); 
                                              c1.ra = (mRxFrame.Df).add2;
                                              // clear wait slots - we got a reception
                                              //we are committing to packet reception at this point.  
                                              //we will launch the ack missles.
                                              mac_rxfrm.enq(MacSWFrame{frame:mRxFrame,dataLength:phy_rxvector.first.length});
                                              ackfrm.enq(MacSWFrame{frame: tagged Cf tagged C1 c1, dataLength: 0});
					   end
                                         else if(cidx >  fromInteger(valueof(DataFrameOctets)) && (mRxFrame.Df).add1 == my_mac_sa)
                                            begin
                                              $display($time, " TB MACVERBOSE %d: RXDATA ENQ cidx %d rxdata: %h", my_mac_sa, cidx, rxdata);
                                              llc_rxdata.enq(rxdata);
                                            end
                                         else if(cidx >=  fromInteger(valueof(DataFrameOctets)) && ((mRxFrame.Df).add1 != my_mac_sa))
 	                                   begin
                                             $display($time, "TB MACVERBOSE %2d: frame did not match mac: %d",my_mac_sa,mRxFrame.Df.add1);
                                           end
				      end
			     4'b0100: begin 
					 $display($time, " MAC null data");
				      end
			     default: begin
					 $display($time, " MAC not handled");
				      end
			  endcase
		       end
	       default : begin // reserved
                          $display($time, " MAC TB unexpected frame type");
			 end
	    endcase
	 end
      
      PhySapStatus_T st = DataInd;


      // use the rx inwfor to determine the end of a packet.
      // this subsumes the old recvDone
      if(cidx == phy_rxvector.first.length)
        begin
          phy_rxvector.deq;
          cidx = 0;
      	  st = Idle;
        end


      rx_idx <= cidx;
      phy_rxdataFIFO.deq;
      phy_sap_rxstatus <= st;
   endrule      
   
   // this is probably not needed any more.
   rule rstTmrEnq(reset_tmr_cca);
     reset_tmr.enq(?);
   endrule

   // might want a rule here that has a fifo for resetting the bkf_tmr


   // why must txfrm be empty here
   // It must be empty because our TX will make cca appear busy..
   // first clause could be busy due to our own ack. so we'll try to ignore it
   // here the difsTime may not be the right thing XXX... could want eifs
   rule mac_set_defer((!wait_for_ack && phy_sap_txstatus==Idle && phy_cca_status==BUSY && 
                        bkf_tmr == 0 && bkf_slots == 0 && !cwActionFIFO.notEmpty && mac_txfrm.notEmpty)); 
      // medium busy during TX time, didn't receive ACK within ACKtimeout
      // prepare for exponential backoff
      // need lfsr here
      // new bfkoff only if we have no present backoff
      cwActionFIFO.enq(Defer);
      $display($time, " MAC %d deferring", my_mac_sa);
   endrule

   Reg#(Bit#(32)) successCounter <- mkReg(0);
   Reg#(Bit#(32)) deferCounter <- mkReg(0);
   Reg#(Bit#(32)) deferActualCounter <- mkReg(0);
   Reg#(Bit#(32)) failureCounter <- mkReg(0);

   rule handleCW;
     CWIndex cwIndexUse = fromInteger(valueof(CWIndexMin));     
     cwActionFIFO.deq;
     case (cwActionFIFO.first)
       Success: begin 
                  successCounter <= successCounter + 1;
                  cwIndex <= fromInteger(valueof(CWIndexMin));     
                  cwIndexUse = fromInteger(valueof(CWIndexMin));     
                  $display($time, " MAC %d CW stats at %d : succ+: %d fail: %d defer: %d deferActual: %d bkf_tmr: %d bkf_slots: %d",
                     my_mac_sa,stat,successCounter, failureCounter, deferCounter, deferActualCounter, bkf_tmr, bkf_slots);
                end
       Failure: begin 
                  failureCounter <= failureCounter + 1;
                  cwIndex <= (cwIndex == fromInteger(valueof(CWIndexMax)))?cwIndex:cwIndex+1;     
                  cwIndexUse = cwIndex;     
                  $display($time, " MAC %d CW stats at %d : succ: %d fail+: %d defer: %d deferActual: %d bkf_tmr: %d bkf_slots: %d",
                     my_mac_sa,stat,successCounter, failureCounter, deferCounter, deferActualCounter, bkf_tmr, bkf_slots);
                end
       Defer: begin 
                  deferCounter <= deferCounter + 1;
                  cwIndexUse = cwIndex;     
                  $display($time, " MAC %d CW stats at %d : succ: %d fail: %d defer+: %d deferActual: %d bkf_tmr: %d bkf_slots: %d",
                     my_mac_sa,stat,successCounter, failureCounter, deferCounter, deferActualCounter, bkf_tmr, bkf_slots);

                end
     endcase

     //  check for fishy condition
     if(cwActionFIFO.first == Success && !(bkf_slots == 0 && bkf_tmr == 0))
       begin
         $display($time, " TB MAC, managed to transmit while bkf timer was alive? Something strange here");
         $finish;
       end 

     // Fix at some point.
     Vector#(TAdd#(1,TSub#(CWIndexMax,CWIndexMin)),Real) realCompressVector = arrayToVector(cwCompressTable);
     let compressVector = map(fromReal,realCompressVector);

     if(bkf_slots == 0 && bkf_tmr == 0)
        begin
          // To do make scheme slightly more robust... should probably make this into some kind
          // of policy module.
          if(cwActionFIFO.first == Defer)
            begin
              deferActualCounter <= deferActualCounter + 1;
            end
          let adjustedCWIndex = cwIndex - fromInteger(valueof(CWIndexMin));
          UInt#(8) raw_rnd = truncate(unpack(backoffLFSR.value)); // 8 bits here as we use 9 bits below
	  FixedPoint#(9,6) rnd_num = fromUInt(raw_rnd); // random number from 15-1023
          FixedPoint#(9,6) compressedFxptRandom = rnd_num*compressVector[adjustedCWIndex];
          Bit#(8) compressedRandom = pack(truncate(fxptGetInt(compressedFxptRandom)));
          Bit#(8) bkf_next = compressedRandom + fromInteger(cwOffsetTable[adjustedCWIndex]);  // do the multiply thing here
	  bkf_slots <= zeroExtend(bkf_next);
          backoffLFSR.next;
          $display($time, " MAC TB %2d: setting CW: %d mac_backoff: %d",my_mac_sa,cwIndex,bkf_next);
     end
   endrule


   // XXX probably can't release a new txframe until CW action fifo is empty.
   // this might create problems once cw handler is put in a sub module.
   rule ack_timeout(ack_tmr == 0 && wait_for_ack);
     ack_tmr <= 0;
     pre_frame_error <= True;
     wait_for_ack <= False;
     $display($time,"TB MAC %d Failure(ack timeout) bkf_slots: %d bkf_tmr: %d", my_mac_sa, bkf_slots, bkf_tmr);
     llc_txstatus.enq(Failure);
     cwActionFIFO.enq(Failure);
   endrule  

   rule update_ifs_tmr (phy_cca_status == IDLE && ifs_tmr < eifsTime && clk_tick);
      $display($time, " MACVERBOSE TB %2d: update_ifs_tmr ifs_tmr=%d",my_mac_sa,ifs_tmr);
      ifs_tmr <= ifs_tmr + 1;
   endrule
   
   rule update_ack_tmr (ack_tmr > 0 && clk_tick && !txFIFO.notEmpty && phy_cca_status == IDLE); // have to wait to complete transmit
      $display($time, " TB MACVERBOSE %2d: update_ack_tmr ack_tmr=%d",my_mac_sa,ack_tmr);
      ack_tmr <= ack_tmr - 1;
   endrule
   
   rule update_bkf_slots(phy_cca_status == IDLE && bkf_slots > 0 && bkf_tmr==0);
      bkf_tmr <= slotTime;
      bkf_slots <= bkf_slots - 1;
   endrule

   // for now we may pay an extended delay due to eifsTimes...
   rule update_bkf_tmr (bkf_tmr > 0 && clk_tick && ifs_tmr >= eifsTime);
      $display($time, " MACVERBOSE %2d: update_bkf_tmr bkf_slt=%d,bkf_tmr=%d",my_mac_sa, bkf_slots,bkf_tmr);
      bkf_tmr <= bkf_tmr - 1;
   endrule
   
   // need to understand this reset ifs
   // may be doing things a bit out of order here
   // also this may block our receipt of packets - if agressive conditions is not right.
   // The ifs timer may still have problems if the packet we get is not an ack, but we expected an ack.  
   // In that case, we probably won't transmit anything but we should set EIFS time.
   rule reset_ifs_tmr; // this rule ought to be subsumed by the rx rule, maybe
      reset_tmr.deq; //Probably don't need a fifo anymore - needless wasted cycle?
      $display($time, " MAC TB %2d: reset ifs", my_mac_sa);
      ifs_tmr <= 0;
   endrule
 
   rule tick;
      if(ctr0 + 1 == fromInteger(valueOf(TicksPerMicrosecond))) 
	 begin
	    //$display($time, " sta=%d, ctr0=%d, ctr1=%d, time=%d",my_mac_sa,ctr0,ctr1,$time);	 
	    ctr1 <= ctr1 + 1;
	    clk_tick.send();
            ctr0 <= 0;
	 end
     else
       begin
         ctr0 <= ctr0 + 1;
       end
      //$display($time, " %2d:state tx=%2d,rx=%2d",my_mac_sa,phy_sap_txstatus,phy_sap_rxstatus);
   endrule
   
   rule doStartSecondary (startSecondary);
      //manipulate bkf slots to start transmission
      bkf_slots <=0;
      bkf_tmr <=0;
      ifs_tmr <= difsTime; 
      $display("MAC phy_sap_rx %d ifs_tmr %d", phy_sap_rxstatus, ifs_tmr);
      startSecondary <= False;
      secondary_ready <= True;
   endrule
   
   interface Get phy_txstart;
      method ActionValue#(BasicTXVector) get();
	 //$display($time, " interface get phy_txstart_req");
         $display($time, " TB MAC %d: interface get txstart", my_mac_sa);
	 let x = phy_txvector.first;
	 phy_txvector.deq;
	 return x;
      endmethod
   endinterface

   interface phy_rxstart = fifoToPut(fifofToFifo(phy_rxvector));

   interface Get phy_txdata;
      method ActionValue#(PhySapData_T) get();
	 $display($time, " TB MACVERBOSE %d: interface get txdata: %h", my_mac_sa, phy_txdataFIFO.first);
	 let x = phy_txdataFIFO.first;

	 phy_txdataFIFO.deq;
   	 
	 PhySapStatus_T st = phy_sap_txstatus;
	 
	 return x;
      endmethod
   endinterface
   
   interface Put phy_rxdata;
      method Action put(PhySapData_T d);
	 $display($time, " TB MACVERBOSE %d: interface rxdata: %h", my_mac_sa, d);
	 phy_rxdataFIFO.enq(d);
      endmethod
   endinterface


   interface Put phy_cca_ind;
      method Action put(PhyCcaStatus_T s);
	 //$display($time, " interface put phy_cca_ind"); 
	 if(phy_cca_status == BUSY && s == IDLE) // Change on Busy -> Idle. 
            begin
	       phy_cca_status <= s;
               $display($time, " MAC TB %d: phy_cca_status: %s",my_mac_sa,(s == IDLE)?"IDLE":"BUSY");
               reset_tmr_cca.send; // is this really okay?  Probably... might have some timing issues sometime
            end
	 if(phy_cca_status == IDLE && s == BUSY) // Change on Idle -> Busy. 
            begin
	       phy_cca_status <= s;
               $display($time, " MAC TB %d: phy_cca_status: %s",my_mac_sa,(s == IDLE)?"IDLE":"BUSY");
            end
	 if(s == CONC) 
            begin
	       //cca status forced to idle
	       phy_cca_status <= IDLE;
	       startSecondary <= True;
               $display($time, " MAC TB %d: CONC SIGNAL phy_cca_status: %s",my_mac_sa,(s == IDLE)?"IDLE":"BUSY");
            end
      endmethod
   endinterface
   
   

   interface Put mac_sw_txframe;
      method Action put(MacSWFrame d); 
                                       // XXX need a guard here.unfortunately in the case of ack, we use this pipeline.
                                       // it would be bad to kill the tx this way
	 $display($time, " TB MAC: interface put llc_mac_tx_frame");
	 mac_txfrm.enq(d);
      endmethod
   endinterface

   interface Get mac_sw_rxframe;
      method ActionValue#(MacSWFrame) get();
	 $display($time, " TB MAC: interface get llc_mac_rx_frame");
	 let x = mac_rxfrm.first;
	 mac_rxfrm.deq;
	 return x;
      endmethod
   endinterface


   interface Put mac_sa;
      method Action put(Bit#(48) a);

	 my_mac_sa <= a;
         Bit#(16) seed = fold(funcXor,unpack(a));
         backoffLFSR.seed((seed==0)?~0:seed);
         $display($time, " TB MAC Setting my MAC: %d seed: %d",a, (seed==0)?~0:seed);
      endmethod
   endinterface

   
  // may eventually have problems here if frames are inserted elsewhere
  // and don't come through rx/tx control.
  interface Put phy_txcomplete; // PHY tells MAC tx is complete
    method Action put(Bit#(0) in);
      $display($time, " TB MAC %d TXFIFO DEQ", my_mac_sa);
      txFIFO.deq; 
    endmethod
  endinterface

  interface mac_sw_txdata = fifoToPut(fifofToFifo(llc_txdata));     // LLC TX data to MAC
  interface mac_sw_rxdata = fifoToGet(fifofToFifo(llc_rxdata));     // RX data from PHY to MAC   
  interface mac_sw_txstatus = fifoToGet(llc_txstatus);  // tell upper level of success/failure   
endmodule
