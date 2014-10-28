import GetPut::*;


interface MAC;
   interface Put#(Bit#(48))           mac_sa;  
   interface Get#(TXVector)           phy_txstart;  // MAC to PHY
   interface Get#(PhySapData_T)       phy_txdata;     // MAC TX data to PHY
   interface Put#(Bit#(0))            phy_txcomplete; // PHY tells MAC tx is complete
   interface Put#(PhyData)            phy_rxdata;     // RX data from PHY to MAC
   interface Put#(PhyCcaStatus_T)     phy_cca_ind;      // carrier sense indication from PHY to MAC
   interface Put#(RXVector)           phy_rxstart;          

   // not really a MAC frame... 
   interface Put#(MacSWFrame)         mac_sw_txframe; // llc to mac tx
   interface Get#(MacSWFrame)         mac_sw_rxframe; // mac to llc rx
   interface Put#(PhySapData_T)       mac_sw_txdata;     // LLC TX data to MAC
   interface Get#(PhySapData_T)       mac_sw_rxdata;     // RX data from PHY to MAC   
   interface Get#(MACTxStatus)        mac_sw_txstatus;  // tell upper level of success/failure   

   interface Get#(RXExternalFeedback) mac_abort;
   
   //aborting transmissions
   interface Put#(Bit#(0))  abortAck;
   interface Get#(Bit#(0))  abortReq; 
endinterface

interface SoftMAC;
   interface Put#(Bit#(48))           mac_sa;  
   interface Get#(TXVector)           phy_txstart;  // MAC to PHY
   interface Get#(PhySapData_T)       phy_txdata;     // MAC TX data to PHY
   interface Put#(Bit#(0))            phy_txcomplete; // PHY tells MAC tx is complete
   interface Put#(PhyData)            phy_rxdata;     // RX data from PHY to MAC
   interface Put#(PhyHints)           phy_rxhints;
   interface Put#(PhyCcaStatus_T)     phy_cca_ind;      // carrier sense indication from PHY to MAC
   interface Put#(RXVector)           phy_rxstart;          

   // not really a MAC frame... 
   interface Put#(MacSWFrame)         mac_sw_txframe; // llc to mac tx
   interface Get#(MacSWFrame)         mac_sw_rxframe; // mac to llc rx
   interface Put#(PhySapData_T)       mac_sw_txdata;     // LLC TX data to MAC
   interface Get#(PhySapData_T)       mac_sw_rxdata;     // RX data from PHY to MAC   
   interface Get#(MACTxStatus)        mac_sw_txstatus;  // tell upper level of success/failure   

   interface Get#(RXExternalFeedback) mac_abort;
   
   //aborting transmissions
   interface Put#(Bit#(0))  abortAck;
   interface Get#(Bit#(0))  abortReq; 
endinterface

//typedef struct 
//{
//   PhyData data;
//   PhyHints hints;
//} SoftPhyData deriving (Bits);
//
//typedef GENERIC_MAC#(PhyData) MAC;
//typedef GENERIC_MAC#(SoftPhyData) SoftMAC;

interface BasicMAC;
   interface Put#(Bit#(48))           mac_sa;  
   interface Get#(BasicTXVector)           phy_txstart;  // MAC to PHY
   interface Get#(PhySapData_T)       phy_txdata;     // MAC TX data to PHY
   interface Put#(Bit#(0))            phy_txcomplete; // PHY tells MAC tx is complete
   interface Put#(PhySapData_T)       phy_rxdata;     // RX data from PHY to MAC
   interface Put#(PhyCcaStatus_T)     phy_cca_ind;      // carrier sense indication from PHY to MAC
   interface Put#(BasicRXVector)           phy_rxstart;          

   // not really a MAC frame... 
   interface Put#(MacSWFrame)         mac_sw_txframe; // llc to mac tx
   interface Get#(MacSWFrame)         mac_sw_rxframe; // mac to llc rx
   interface Put#(PhySapData_T)       mac_sw_txdata;     // LLC TX data to MAC
   interface Get#(PhySapData_T)       mac_sw_rxdata;     // RX data from PHY to MAC   
   interface Get#(MACTxStatus)        mac_sw_txstatus;  // tell upper level of success/failure   

   interface Get#(RXExternalFeedback) mac_abort;
endinterface


typedef enum {
  Success,
  Failure
} MACTxStatus deriving (Bits,Eq);


// CRC-32 (IEEE802.3), polynomial 0 1 2 4 5 7 8 10 11 12 16 22 23 26 32.

//   3  2            1           0        
//   2109 8765 4321 0987 6543 2109 8765 4321 0
// 'b1000 0010 0110 0000 1000 1110 1101 1011 1 CRCPoly;

typedef 'b100000100110000010001110110110111 CRCPoly;
// 'b1100 0111 0000 0100 1101 1101 0111 1011 CRCPolyResult;
// 'hc704dd7b 
typedef 'b11000111000001001101110101111011 CRCPolyResult;

typedef 1 ByPassDataConf; // DataConf is required as per Clause 12.3.5.3
                          // However if you want to bypass it, 
                          // set this field to 1 

// PHY-SAP

typedef 3 CWIndexMin; 
typedef 8 CWIndexMax; // This maybe should be 10?
typedef Bit#(TAdd#(1,TLog#(CWIndexMax))) CWIndex;

Real cwCompressTable[valueof(CWIndexMax)-valueof(CWIndexMin)+1] = 
                       { 31/32,  //3
                         15/16,  //4
                         7/8,    //5
                         3/4,    //6
                         1/2,    //7               
                         0/1
                       };

// would like to define this in terms of cwCompressTable, or a generator but too lazy
Integer cwOffsetTable[valueof(CWIndexMax)-valueof(CWIndexMin)+1] = 
                        { 7,
                          15,
                          31,
                          63,
                          127,
                          255
                        };


typedef Bit#(8) PhySapData_T;

typedef Bit#(32) FCS;
typedef TDiv#(SizeOf#(FCS),8) FCSOctets;

typedef enum {
   Idle = 0,      
   DataReq = 1,   
   DataInd = 2,   
   DataConf = 3,  
   TxStart = 4,  
   TxStartConf = 5, 
   TxEndReq = 6,    
   TxEndConf = 7,   
   CcaResetReq = 8, 
   CcaResetConf = 9,
   CcaResetInd = 10,
   RxStartInd = 11, 
   RxEndInd = 12,   
   Wait = 13 
   } PhySapStatus_T deriving(Eq,Bits);




typedef enum {
  Management = 0,
  Control = 1, 
  Data = 2
}  MACFrameType deriving (Eq,Bits);

`define FRAME_CTL_SUBTYPE_RTS 'b1011
`define FRAME_CTL_SUBTYPE_CTS 'b1100
`define FRAME_CTL_SUBTYPE_ACK 'b1101
`define FRAME_CTL_SUBTYPE_SR_ACK 'b0101

typedef enum {
   NoError,
   FormatViolation,
   CarrierLost,
   UnsupportedRate
   } RXERROR_T deriving(Eq,Bits);

typedef enum {
   IDLE,
   BUSY,
   CONC
   } PhyCcaStatus_T deriving(Eq,Bits);

// Clause 7.1.2
typedef 2304 MSDUSize;  // octets
typedef 20   IcvPlusIv; // integrity check value + initialization vector


typedef 6     XtraBts;    // 298+8 = 304, which is 38 bytes


// frame size
//typedef TMax#(TMax#(DataFrame_T,MgmtFrame_T),
//              TMax#(TMax#(TMax#(CommonCtlFrame1_T,CommonCtlFrame2_T),PsPollFrame_T),
//                    TMax#(BlkAckReq_T,BlkAck_T))) FrameSz;       // max size rounded off to 2362 octets

typedef SizeOf#(DataFrame_T) FrameSz;
typedef TDiv#(FrameSz,8)  FrameSzBy;     // size of data frame with one byte data 
typedef TLog#(FrameSzBy)   FrameIdx;      // bits required to index 36
typedef SizeOf#(CommonCtlFrame1_T) FrameC1Sz;
typedef TDiv#(FrameC1Sz,8)  FrameC1SzBy;
typedef SizeOf#(CommonCtlFrame2_T) FrameC2Sz;
typedef TDiv#(FrameC2Sz,8)  FrameC2SzBy;
typedef SizeOf#(SoftRateAck) FrameSoftRateAckSz;
typedef TDiv#(FrameSoftRateAckSz,8) FrameSoftRateAckSzBy;

// Clause 17.4.4
// OFDM PHY Characteristics for 20 MHz channel spacing
// time in micro seconds

typedef 9    SlotTime;        // micro seconds
typedef 16   SIFSTime;        // micro seconds
typedef 25   PhyRxStartDelay; // micro seconds
typedef 4095 MPDUMaxLength; 



//Clause 7.2.2
typedef TDiv#(SizeOf#(DataFrame_T),8) DataFrameOctets;
typedef TDiv#(SizeOf#(MgmtFrame_T),8) ManagementFrameOctets;



//Clause 10.4.3
typedef struct {
   Bit#(16) aSlotTime;
   Bit#(16) aSIFSTime;
//    Bit#(16) aCCATime;
//    Bit#(16) aPHY_RX_START_Delay;
//    Bit#(16) aRxTxTurnaroundTime;
//    Bit#(16) aTxPLCPDelay;
//    Bit#(16) aRxPLCPDelay;
//    Bit#(16) aRxTxSwitchTime;
//    Bit#(16) aTxRampOnTime;
//    Bit#(16) aTxRampOffTime;
//    Bit#(16) aTxRFDelay;
//    Bit#(16) aRxRFDelay;
//    Bit#(16) aAirPropagationTime;
//    Bit#(16) aMACProcessingDelay;
//    Bit#(16) aPreambleLength;
//    Bit#(16) aPLCPHeaderLength;
//    Bit#(16) aMPDUDurationFactor;
   Bit#(16) aMPDUMaxLength;
   Bit#(16) aCWmin;
   Bit#(16) aCWmax;
   } PlmeCharacteristics_T deriving(Eq,Bits);

// MAC Frame

typedef struct {
   Bit#(2) prot_ver;
   MACFrameType type_val;
   Bit#(4) subtype_val;
   Bit#(1) to_ds;
   Bit#(1) from_ds;
   Bit#(1) more_frag;
   Bit#(1) retry;
   Bit#(1) pwr_mgt;
   Bit#(1) more_data;
   Bit#(1) protd_data;
   Bit#(1) order;
   } FrameCtl_T deriving(Eq,Bits); // 16 bits

typedef struct {
   Bit#(4) frag_num;
   Bit#(12) seq_num;
   } SequenceCtl_T deriving(Eq,Bits); // 16 bits



typedef struct {
   FrameCtl_T     frame_ctl;
   Bit#(16)       dur_id; 
   Bit#(48)       add1; 
   Bit#(48)       add2; 
   Bit#(48)       add3; 		
   SequenceCtl_T  seq_ctl;
   Bit#(48)       add4; 		   
   Bit#(16)       qos_ctl;
} DataFrame_T deriving(Eq,Bits); 


typedef struct {
   FrameCtl_T     frame_ctl;
   Bit#(16)       dur_id; 
   Bit#(48)       add1; 
   Bit#(48)       sa; 
   Bit#(48)       bssid; 	
   SequenceCtl_T  seq_ctl;	
} MgmtFrame_T deriving(Eq,Bits);

typedef struct {
   FrameCtl_T frame_ctl;
   Bit#(16)   dur; // duration
   Bit#(48)   ra;  // rx address
   Bit#(48)   ta;  // tx address
   } CommonCtlFrame2_T deriving(Eq,Bits);

typedef TDiv#(SizeOf#(CommonCtlFrame2_T),8)CommonCtlFrame2Octets;

typedef struct {
   FrameCtl_T frame_ctl;
   Bit#(16)   dur; // duration
   Bit#(48)   ra; // rx address
   Bit#(8)    avg_ber; // average bit error rate
} SoftRateAck deriving(Eq,Bits);

typedef TDiv#(SizeOf#(SoftRateAck),8) SoftRateAckOctets;

typedef struct {
   FrameCtl_T frame_ctl;
   Bit#(16)   dur; // duration
   Bit#(48)   ra;  // rx address
   } CommonCtlFrame1_T deriving(Eq,Bits); // 

typedef TDiv#(SizeOf#(CommonCtlFrame1_T),8)CommonCtlFrame1Octets;

function Integer controlFrameSizeInt(Bit#(4) subtype);
   return case (subtype) 
      `FRAME_CTL_SUBTYPE_RTS: valueOf(CommonCtlFrame2Octets);
      `FRAME_CTL_SUBTYPE_CTS: valueOf(CommonCtlFrame1Octets);
      `FRAME_CTL_SUBTYPE_ACK: valueOf(CommonCtlFrame1Octets);
      `FRAME_CTL_SUBTYPE_SR_ACK: valueOf(SoftRateAckOctets);
      default: 0;
   endcase;
endfunction

function Integer frameSizeInt(FrameCtl_T ctrl);
   return case (ctrl.type_val)
      Management: valueof(ManagementFrameOctets);
      Control: controlFrameSizeInt(ctrl.subtype_val);
      Data: valueOf(DataFrameOctets);
   endcase;
endfunction

function PhyPacketLength frameSize(FrameCtl_T ctl);
   return fromInteger(frameSizeInt(ctl));
endfunction

typedef union tagged {
   CommonCtlFrame1_T C1;
   CommonCtlFrame2_T C2;
   PsPollFrame_T Poll;
   BlkAckReq_T Bar;
   BlkAck_T Ba;
   SoftRateAck SoftAck;
   } CtlFrame_T deriving(Eq,Bits);

typedef union tagged {
   DataFrame_T Df;
   MgmtFrame_T Mf;
   CtlFrame_T Cf;
   } MacFrame_T deriving(Eq,Bits);
   

// This is the frame we use as a communication to/from the SW MAC.  They will 
// live above us. 
typedef struct {
  Bit#(FrameSz) frame;
  PhyPacketLength dataLength;
} MacSWFrame deriving(Bits,Eq);

function FrameCtl_T frameCtl(f x) provisos (Bits#(f,n),Add#(n,s,256));
   DataFrame_T df = unpack({ pack(x), 0 });
   return df.frame_ctl;
endfunction

function Bit#(FrameSz) packFrame(f x) provisos (Bits#(f,n),Add#(n,s,256));
   return { pack(x), 0 };
endfunction

function f unpackFrame(Bit#(FrameSz) x) provisos (Bits#(f,n),Add#(n,s,256));
   return unpack(truncate(x >> fromInteger(valueOf(s))));
endfunction

typedef CommonCtlFrame2_T RtsFrame_T;
typedef CommonCtlFrame1_T CtsFrame_T;
typedef CommonCtlFrame1_T AckFrame_T;
typedef CommonCtlFrame2_T CfEndFrame_T; // BSSID(TA)
typedef CommonCtlFrame2_T CfEndCfAckFrame_T; // BSSID(TA)

typedef struct {
   FrameCtl_T frame_ctl;
   Bit#(16)   aid; // assigned by AP to the tx STA. 2 MSB set to 1.
   Bit#(48)   ra;  // same as BSSID, address of STA 
   Bit#(48)   ta;  // tx address
   } PsPollFrame_T deriving(Eq,Bits);


typedef struct {
   Bit#(12) res;
   Bit#(4)  tid;
   } BaCtl_T deriving(Eq,Bits);

typedef struct {
   Bit#(4)  frag_num;
   Bit#(12) start_seq_num;
   } BlkAckSeqCtl_T deriving(Eq,Bits);

typedef struct {
   FrameCtl_T frame_ctl;
   Bit#(16)   dur; // duration
   Bit#(48)   ra;  //rx address
   Bit#(48)   ta;  //tx address
   BaCtl_T   bar_ctl; 
   BlkAckSeqCtl_T ba_seq_ctl;
   } BlkAckReq_T deriving(Eq,Bits);


typedef struct {
   FrameCtl_T     frame_ctl;
   Bit#(16)       dur; // duration
   Bit#(48)       ra;  //rx address
   Bit#(48)       ta;  //tx address
   BaCtl_T        ba_ctl; 
   BlkAckSeqCtl_T ba_seq_ctl;
//   Bit#(1024)    ba_bitmap; //128 octects XXX Fixme
   } BlkAck_T deriving(Eq,Bits);

typedef  Bit#(16) AuthAlgNumField_T;
typedef  Bit#(16) AuthTraSeqNumField_T;
typedef  Bit#(16) BeaconIntField_T;

typedef struct {
   Bit#(1) ess;
   Bit#(1) ibss;
   Bit#(1) cf_pollable;
   Bit#(1) cf_poll_req;
   Bit#(1) priv;
   Bit#(1) short_pre;
   Bit#(1) pbcc;
   Bit#(1) ch_agil;
   Bit#(1) sp_mgmt;
   Bit#(1) qos;
   Bit#(1) short_slot_time;
   Bit#(1) apsd;
   Bit#(1) reserved;
   Bit#(1) dsss_ofdm;
   Bit#(1) del_blk_ack;
   Bit#(1) imm_blk_ack;
   } CapInfoField_T deriving(Eq,Bits);

typedef Bit#(48) CurApAddrField_T;
typedef Bit#(16) ListIntField_T;
typedef Bit#(16) ReasonCodeField_T;
typedef Bit#(16) AidField_T;
typedef Bit#(16) StatCodeField_T;
typedef Bit#(64) TimeStampField_T;

typedef struct {
   Bit#(8) cat;
   //variable action_det;
   } ActionField_T deriving(Eq,Bits);

typedef Bit#(8) DialotTknField_T;
typedef Bit#(16) DlsTimeoutField_T;


typedef struct {
   Bit#(1)  reserved;
   Bit#(1)  blk_ack_policy;
   Bit#(4)  tid;
   Bit#(10) buff_sz;
   } BlkAckParamSetField_T deriving(Eq,Bits);

typedef Bit#(16) BlkAckTimeoutField_T;

typedef struct {
   Bit#(11) reserved;
   Bit#(11) init;
   Bit#(4)  tid;
   } DelbaParamField_T deriving(Eq,Bits);

typedef struct {
   Bit#(4) edca_param_set;
   Bit#(1) q_ack;
   Bit#(1) q_req;
   Bit#(1) txop_req;
   Bit#(1) reserved;
   } QosInfoApField_T  deriving(Eq,Bits);

typedef struct {
   Bit#(1) ac_vo_flag;
   Bit#(1) ac_vi_flag;
   Bit#(1) ac_bk_flag;
   Bit#(1) ac_be_flag;
   Bit#(1) q_ack;
   Bit#(1) max_sp_len;
   Bit#(1) more_data_ack;
   } QosInfoNonApField_T deriving(Eq,Bits);

typedef struct {
   Bit#(8) elem_id;
   Bit#(8) len;
   } MgmtHdrField_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(256) ssid;
   } SsidElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(64) rates;
   } SupRatesElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(16) dwell_time;
   Bit#(8)  hop_set;
   } FhParamSetElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8)  cur_ch;
   } DsParamSetElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8)  cfp_cnt;
   Bit#(8)  cfp_period;
   Bit#(16) cfp_max_dur;
   Bit#(16)  cfp_dur_rem;
   } CfParamSetElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8)  dtim_cnt;
   Bit#(8)  dtim_per;
   Bit#(8)  bitmap_ctl;
   Bit#(2008)  par_vir_bitmap; // variable 1-251 octet
   } TimElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(16) atim_win;
   } IbssParamSetElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(2024) chal_txt; // variable 1-253 octets
   } ChalTxtElement_T deriving(Eq,Bits);

// variable country info element
typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) first_ch_num;
   Bit#(8) num_of_ch;
   Bit#(8) max_tx_pwr;
   } CountryElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) prime_rdx;
   Bit#(8) num_of_ch;
   } HopPatParamElement_T deriving(Eq,Bits);

// variable hoppng pattern table info

// variable reqest information

// ERP information element

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(2040) ext_sup_rates; // variable 1-255 octets
   } ExtSupRatesElement_T deriving(Eq,Bits);  

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) loc_pwr_constr;
   } PowConstrElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) min_tx_pwr_cap;
   Bit#(8) max_tx_pwr_cap;
   } PwrCapElement_T deriving(Eq,Bits);

typedef MgmtHdrField_T TpcReqElement_T;

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) len;
   Bit#(8) tx_pwr;
   Bit#(8) lnk_margin;		
   } TpcRepElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(1) first_ch_num;
   Bit#(1) num_of_ch;	
   } SupChElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) ch_sw_mode;
   Bit#(8) new_ch_num;
   Bit#(8) ch_sw_cnt;
   } ChSwAnnElement_T deriving(Eq,Bits);


typedef struct {
   Bit#(1) reserved;
   Bit#(1) en;
   Bit#(1) req;
   Bit#(1) rep;
   Bit#(56) reserved1;
   } MeasReqMode_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) meas_tkn;
   Bit#(8) meas_req_mode;
   Bit#(8) meas_type;
   MeasReqMode_T meas_req;
   } MeasReqElement_T deriving(Eq,Bits);

typedef struct {
   Bit#(1) late;
   Bit#(1) incap;
   Bit#(1) refu;
   Bit#(56) reserved;
   } MeasRepModeField_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) meas_tkn;
   Bit#(8) meas_req_mode;
   Bit#(8) meas_type;
   MeasRepModeField_T meas_rep;
   } MeasRepElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) quiet_cnt;
   Bit#(8) quiet_per;
   Bit#(16) quiet_dur;
   Bit#(16) quiet_offset;
   } QuietElement_T deriving(Eq,Bits);

typedef struct {
   Bit#(8) ch_num;
   Bit#(8) map;
   } ChMapField_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(48) dfs_ownr;
   Bit#(8) dfs_rec_int;
   //ChMapField_T ch_map variable 2*n
   } IbssDfsElement_T deriving(Eq,Bits);


typedef struct {
   MgmtHdrField_T hdr;
   Bit#(16) ver;
   Bit#(32) grp_cip_suite;
   Bit#(16) pair_cip_suite_cnt;
   // Bit#(48-m) pair_cip_suite_lst;
   Bit#(16) akm_suite_cnt;
   //Bit#(49-n) akm_cap;
   Bit#(16) rsn_cap;
   Bit#(16) pmkid_cnt;
   // Bit#(128-s) pmki_dlist;
   }RsnElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(24) oui;
   Bit#(2040) ven_spec_cont; // n-3, (n=3,255)
   }VenSpecElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   //Bit#(n) cap;
   }ExtCapElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(16) sta_cnt;
   Bit#(8) ch_util;
   Bit#(16) avail_adm_cap;
   }BssLoadElement_T deriving(Eq,Bits);

typedef struct {
   Bit#(4)  aifsn;
   Bit#(1)  acm;
   Bit#(2) aci;
   Bit#(1)  reserved;
   } AciAifsnField_T deriving(Eq,Bits);

typedef struct {
   Bit#(4) ecwmin;
   Bit#(4) ecwmax;
   }EcwField_T deriving(Eq,Bits);

typedef struct {
   AciAifsnField_T aci_aifsn;
   EcwField_T ecw;
   Bit#(16) txop_limit;
   } AcParamRecField_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) qos_info;
   Bit#(8) reserved;
   AcParamRecField_T ac_be;
   AcParamRecField_T ac_bk;
   AcParamRecField_T ac_vi;
   AcParamRecField_T ac_vo;
   } EdcaParamSetElement_T deriving(Eq,Bits);

typedef struct {
   Bit#(1) tr_type;
   Bit#(4) tsid;
   Bit#(2) dir;
   Bit#(2) acc_pol;
   Bit#(1) agg;
   Bit#(1) apsd;
   Bit#(1) usr_pri;
   Bit#(3) ts_ack_pol;
   Bit#(1) sched;
   Bit#(7) reserved;
   } TsInfoField_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   TsInfoField_T ts_info;
   Bit#(16) nom_msdu_sz;
   Bit#(16) max_msdu_sz;
   Bit#(32) min_ser_int;
   Bit#(32) max_ser_int;
   Bit#(32) inactiv_int;
   Bit#(32) susp_int;
   Bit#(32) ser_start_time;
   Bit#(32) min_data_rate;
   Bit#(32) mean_data_rate;
   Bit#(32) peak_data_rate;
   Bit#(32) burst_sz;
   Bit#(32) del_bou;
   Bit#(32) min_phy_rate;
   Bit#(16) sur_bwd_allow;
   Bit#(16) med_tim;
   } TspecElement_T deriving(Eq,Bits);

typedef struct {
   Bit#(8) class_type;
   Bit#(8) class_mask;
   Bit#(2016) class_param;
   } FrameClassField_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) usr_pri;
   FrameClassField_T frm_class;
   } TclasElement_T deriving(Eq,Bits);


typedef struct {
   MgmtHdrField_T hdr;
   Bit#(32) del;
   } TsDelayElement_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) proc;
   } TclasProcElement_T deriving(Eq,Bits);

typedef struct {
   Bit#(1) agg;
   Bit#(4) tsid;
   Bit#(2) dir;
   Bit#(9) reserved;
   } SchInfoField_T deriving(Eq,Bits);

typedef struct {
   MgmtHdrField_T hdr;
   SchInfoField_T sch_info;
   Bit#(32) ser_start_time;
   Bit#(32) ser_int;
   Bit#(16) spec_int;
   } SchedElement_T deriving(Eq,Bits);


typedef struct {
   MgmtHdrField_T hdr;
   Bit#(8) qos_info;
   } QosCapElement_T deriving(Eq,Bits);
		
typedef struct {
   TimeStampField_T tim_stmp;
   BeaconIntField_T beacon_int;
   CapInfoField_T cap_info;
   SsidElement_T ssid;
   SupRatesElement_T sup_rates;
   FhParamSetElement_T fh_param_set;
   DsParamSetElement_T ds_param_set;
   CfParamSetElement_T cf_param_set;
   IbssParamSetElement_T ibss_param_set;
   TimElement_T tim;
   // other elements are dependent on dot11 settings
   }BeaconFrame_T;


// Slightly ugly way to enforce the size of certain types.
(*synthesize*)
module mkMACDataTypeAssertions (Empty);
if(valueof(SizeOf#(MACFrameType)) != 2)
  begin
   error("illegal MACFrameType size");
  end

if(valueof(SizeOf#(CommonCtlFrame2_T)) != valueof(CommonCtlFrame2Octets) * 8)
  begin
   error("illegal CommonCtlFrame2 size");
  end

if(valueof(SizeOf#(CommonCtlFrame1_T)) != valueof(CommonCtlFrame1Octets) * 8)
  begin
   error("illegal CommonCtlFrame1 size");
  end

if(valueof(SizeOf#(DataFrame_T)) != valueof(DataFrameOctets) * 8)
  begin
   error("illegal DataFrameOctets size");
  end

if(valueof(FrameSz) != valueof(FrameSzBy) * 8)
  begin
   error("illegal FrameSz size");
  end

endmodule


