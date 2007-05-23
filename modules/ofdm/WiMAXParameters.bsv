// WiMAX 802.16 Parameters
import Complex::*;
import Connectable::*;
import GetPut::*;
import Vector::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
// import LibraryFunctions::*;

// Global Parameters:
typedef enum {
   R0,  // BPSK 1/2
   R1,  // QPSK 1/2
   R2,  // QPSK 3/4
   R3,  // 16-QAM 1/2
   R4,  // 16-QAM 3/4
   R5,  // 64-QAM 2/3
   R6   // 64-QAM 3/4
} Rate deriving(Eq, Bits);

// may be an extra field for DL: sendPremable
typedef struct {
   Bool       firstSymbol; 
   Rate       rate;
   CPSizeCtrl cpSize;
} TXGlobalCtrl deriving(Eq, Bits);

typedef 2  TXFPIPrec; // fixedpoint integer precision
typedef 14 TXFPFPrec; // fixedpoint fractional precision

typedef 2  RXFPIPrec; // rx fixedpoint integer precision
typedef 14 RXFPFPrec; // rx fixedpoint fractional precision
typedef TXGlobalCtrl RXGlobalCtrl; // same as tx

// Local Parameters:

// Scrambler:
typedef  8 ScramblerDataSz;    
typedef 15 ScramblerShifterSz;
Bit#(ScramblerShifterSz) scramblerGenPoly = 'b110000000000000;
typedef ScramblerCtrl#(ScramblerDataSz,ScramblerShifterSz) 
	TXScramblerCtrl;

typedef struct {
   TXScramblerCtrl  scramblerCtrl;
   TXGlobalCtrl     globalCtrl;
} TXScramblerAndGlobalCtrl deriving(Eq, Bits); 

function TXScramblerCtrl 
   scramblerMapCtrl(TXScramblerAndGlobalCtrl ctrl);
   return ctrl.scramblerCtrl;
endfunction

function TXGlobalCtrl 
   scramblerConvertCtrl(TXScramblerAndGlobalCtrl ctrl);
    return ctrl.globalCtrl;
endfunction

//Reed Solomon Encoder:
typedef 8 ReedEncoderDataSz;

function ReedSolomonCtrl#(8) reedEncoderMapCtrl(TXGlobalCtrl ctrl);
    return case (ctrl.rate) matches
               R0   : ReedSolomonCtrl{in:12, out:0};
               R1   : ReedSolomonCtrl{in:24, out:8};
               R2   : ReedSolomonCtrl{in:36, out:4};
               R3   : ReedSolomonCtrl{in:48, out:16};
               R4   : ReedSolomonCtrl{in:72, out:8};
               R5   : ReedSolomonCtrl{in:96, out:12};
               R6   : ReedSolomonCtrl{in:108, out:12};
           endcase;
endfunction

// Conv. Encoder:
typedef 8  ConvEncoderInDataSz;
typedef TMul#(2,ConvEncoderInDataSz) ConvEncoderOutDataSz;
typedef  7 ConvEncoderHistSz;
Bit#(ConvEncoderHistSz) convEncoderG1 = 'b1111001;
Bit#(ConvEncoderHistSz) convEncoderG2 = 'b1011011;

// Puncturer:
typedef ConvEncoderOutDataSz        PuncturerInDataSz;
typedef 24                          PuncturerOutDataSz;
typedef TMul#(2,PuncturerInDataSz)  PuncturerInBufSz;  // to be safe 2x inDataSz
typedef TMul#(2,PuncturerOutDataSz) PuncturerOutBufSz; // to be safe 2x outDataSz 
typedef TDiv#(PuncturerInDataSz,4)  PuncturerF1Sz; // no. of 2/3 in parallel
typedef TDiv#(PuncturerInDataSz,6)  PuncturerF2Sz; // no. of 3/4 in parallel
typedef TDiv#(PuncturerInDataSz,10) PuncturerF3Sz; // no. of 5/6 in parallel

function Bit#(3) puncturerF1 (Bit#(4) x);
   return {x[3:3],x[1:0]};
endfunction // Bit
   
function Bit#(4) puncturerF2 (Bit#(6) x);
   return {x[4:3],x[1:0]};
endfunction // Bit

// not used in WiFi   
function Bit#(6) puncturerF3 (Bit#(10) x);
   return {x[8:7],x[4:3],x[1:0]};
endfunction // Bit

function PuncturerCtrl puncturerMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: Half;
	     R1: TwoThird;
	     R2: FiveSixth;
	     R3: TwoThird;
	     R4: FiveSixth;
	     R5: ThreeFourth;
	     R6: FiveSixth;
	  endcase; // case(rate)
endfunction // Bit  

// Encoder: (Construct from ConvEncoder & Puncturer for wifi)
typedef ReedEncoderDataSz   EncoderInDataSz;
typedef PuncturerOutDataSz  EncoderOutDataSz;


// Interleaver:
typedef PuncturerOutDataSz  InterleaverDataSz;
typedef 192                 MinNcbps;

// used for both interleaver, mapper
function Modulation modulationMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: BPSK;
	     R1: QPSK;
	     R2: QPSK;
	     R3: QAM_16;
	     R4: QAM_16;
	     R5: QAM_64;
	     R6: QAM_64;
          endcase;
endfunction

function Integer interleaverGetIdx(Modulation m, Integer k);
   Integer s = 1;  
   Integer ncbps = valueOf(MinNcbps);
   case (m)
      BPSK:   
      begin
	 ncbps = ncbps;
	 s = 1;
      end
      QPSK:   
      begin
	 ncbps = 2*ncbps;
	 s = 1;
      end
      QAM_16: 
      begin
	 ncbps = 4*ncbps;
	 s = 2;
      end
      QAM_64: 
      begin
	 ncbps = 6*ncbps;
	 s = 3;
      end
   endcase // case(m)
   Integer i = (ncbps/12) * (k%12) + k/12;
   Integer f= (i/s);
   Integer j = s*f + (i + ncbps - (12*i/ncbps))%s;
   return (k >= ncbps) ? k : j;
endfunction

//Mapper:
typedef InterleaverDataSz MapperInDataSz;
typedef 192               MapperOutDataSz;
// mapperNegateInput = True implies: map 1 to -ve map 0 to +ve
//                     False implies: mape 1 to +ve map 1 to -ve
Bool mapperNegateInput = True; 

//Pilot:
typedef  MapperOutDataSz  PilotInDataSz;
typedef  256              PilotOutDataSz;
typedef   11              PilotPRBSSz;
Bit#(PilotPRBSSz) pilotPRBSMask = 'b10100000000;
Bit#(PilotPRBSSz) pilotInitSeq  = 'b01010101010; 
// DL = 'h11111111100 (spec say 7FF, but we start after preamble)
// UL = 'h01010101010 (spec say 555, but we start after preamble)

function PilotInsertCtrl pilotMapCtrl(TXGlobalCtrl ctrl);
   return ctrl.firstSymbol ? PilotRst : PilotNorm;
endfunction 

function Symbol#(PilotOutDataSz,TXFPIPrec,TXFPFPrec) 
   pilotAdder(Symbol#(PilotInDataSz,TXFPIPrec,TXFPFPrec) x,
	      Bit#(1) ppv);
   
   Integer i =0, j = 0;
   // assume all guards initially
   Symbol#(PilotOutDataSz,TXFPIPrec,TXFPFPrec) syms = replicate(cmplx(0,0));

   // data carriers
   for(i = 29; i < 40; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 41; i < 65; i = i + 1, j = j + 1)
      syms[i] = x[j]; 
   for(i = 66; i < 90 ; i = i + 1, j = j + 1)
      syms[i] = x[j];  
   for(i = 91; i < 115 ; i = i + 1, j = j + 1)
      syms[i] = x[j];   
   for(i = 116; i < 128 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 129; i < 141 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 142; i < 166 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 167; i < 191 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 192; i < 216 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 217; i < 228 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   
   //pilot carriers 
   syms[40]  = mapBPSK(True,  ppv);  // UL: T, DL: T
   syms[65]  = mapBPSK(False, ppv);  // UL: F, DL: F
   syms[90]  = mapBPSK(True,  ppv);  // UL: T, DL: T
   syms[115] = mapBPSK(False, ppv);  // UL: F, DL: F
   syms[141] = mapBPSK(True,  ppv);  // UL: T, DL: F
   syms[166] = mapBPSK(True,  ppv);  // UL: T, DL: T
   syms[191] = mapBPSK(True,  ppv);  // UL: T, DL: F
   syms[216] = mapBPSK(True,  ppv);  // UL: T, DL: T
   
   return syms;
endfunction

// FFT/IFFT:
typedef PilotOutDataSz FFTIFFTSz;
typedef 32             FFTIFFTNoBfly;

// CPInsert:
typedef FFTIFFTSz CPInsertDataSz;

function CPInsertCtrl cpInsertMapCtrl(TXGlobalCtrl ctrl);
   // UL: SendLong, DL: SendBoth
   let fstEle = ctrl.firstSymbol ? SendLong : SendNone; 
   return tuple2(fstEle, ctrl.cpSize);
endfunction

// Synchronizer:
// specific for OFDM specification
typedef 64  SSLen;        // short symbol length (auto correlation delay 16)
typedef 128 LSLen;        // long symbol length (auto correlation delay 64)
typedef 320 LSStart;      // when the long symbol start
typedef 640 SignalStart;  // when the signal (useful data) start
typedef 320 SymbolLen;    // one symbol length
// implementation parameters
typedef 192 SSyncPos;      // short symbol synchronization position ( 2*SSLen <= this value < LBStart)
typedef 448 LSyncPos;      // long symbol synchronization position  ( LSStart <= this value < SinglaStart)       
typedef 16  FreqMeanLen;   // how many samples we collect to calculate CFO (power of 2, at most 32, bigger == more tolerant to noise)
typedef 720 TimeResetPos;  // reset time if coarCounter is larger than this, must be bigger than SignalStart
typedef 2   CORDICPipe;    // number of pipeline stage of the cordic
typedef 16  CORDICIter;    // number of cordic iterations (max 16 iterations, must be multiple of CORDICPIPE)
typedef RXFPIPrec  SyncIntPrec;   // number of integer bits for internal arithmetic
typedef RXFPFPrec  SyncFractPrec; // number of fractional bits for internal arithmetic 

// Unserializer:
typedef FFTIFFTSz  UnserialOutDataSz;

// ChannelEstimator:
typedef UnserialOutDataSz  CEstInDataSz;
typedef PilotInDataSz      CEstOutDataSz;

function Symbol#(CEstOutDataSz,RXFPIPrec,RXFPFPrec) pilotRemover
   (Symbol#(CEstInDataSz,RXFPIPrec,RXFPFPrec) x);   
   Integer i =0, j = 0;
   // assume all guards initially
   Symbol#(CEstOutDataSz,RXFPIPrec,RXFPFPrec) syms = newVector;
  
   // data carriers
   for(i = 29; i < 40; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 41; i < 65; i = i + 1, j = j + 1)
      syms[j] = x[i]; 
   for(i = 66; i < 90 ; i = i + 1, j = j + 1)
      syms[j] = x[i];  
   for(i = 91; i < 115 ; i = i + 1, j = j + 1)
      syms[j] = x[i];   
   for(i = 116; i < 128 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 129; i < 141 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 142; i < 166 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 167; i < 191 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 192; i < 216 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 217; i < 228 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   return syms;
endfunction

// Demapper:
typedef CEstOutDataSz  DemapperInDataSz;
typedef MapperInDataSz DemapperOutDataSz;

Bool demapperNegateOutput = mapperNegateInput;

// Deinterleaver:
typedef DemapperOutDataSz DeinterleaverDataSz;

function Integer deinterleaverGetIndex(Modulation m, Integer j);
   Integer s = 1;  
   Integer ncbps = valueOf(MinNcbps);
   case (m)
      BPSK:  
      begin
	 ncbps = ncbps;
	 s = 1;
      end
      QPSK:  
      begin
	 ncbps = 2*ncbps;
	 s = 1;
      end
      QAM_16:
      begin
	 ncbps = 4*ncbps;
	 s = 2;
      end
      QAM_64:
      begin
	 ncbps = 6*ncbps;
	 s = 3;
      end
   endcase // case(m)
   Integer f = (j/s);
   Integer i = s*f + (j + (12*j/ncbps))%s;
   Integer k = 12*i-(ncbps-1)*(12*i/ncbps);
   return (j >= ncbps) ? j : k;
endfunction			  

// Depuncturer:
typedef DemapperOutDataSz  DepuncturerInDataSz;
typedef PuncturerInDataSz  DepuncturerOutDataSz;
typedef TMul#(2,DepuncturerInDataSz)   DepuncturerInBufSz;  // to be safe 2x inDataSz
typedef TMul#(2,DepuncturerOutDataSz)  DepuncturerOutBufSz; // to be safe 2x outDataSz 
typedef TDiv#(DepuncturerOutDataSz,4)  DepuncturerF1Sz;     // no. of 2/3 in parallel
typedef TMul#(DepuncturerF1Sz,3)       DepuncturerF1InSz;   
typedef TMul#(DepuncturerF1Sz,4)       DepuncturerF1OutSz;
typedef TDiv#(DepuncturerOutDataSz,6)  DepuncturerF2Sz;     // no. of 3/4 in parallel
typedef TMul#(DepuncturerF2Sz,4)       DepuncturerF2InSz;   
typedef TMul#(DepuncturerF2Sz,6)       DepuncturerF2OutSz;
typedef TDiv#(DepuncturerOutDataSz,10) DepuncturerF3Sz;     // no. of 5/6 in parallel
typedef TMul#(DepuncturerF3Sz,6)       DepuncturerF3InSz;   
typedef TMul#(DepuncturerF3Sz,10)      DepuncturerF3OutSz;

function DepunctData#(4) dp1 (DepunctData#(3) x);
   DepunctData#(4) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[2] = x[1];
   outVec[3] = x[2];
   return outVec;
endfunction // Bit
   
function DepunctData#(6) dp2 (DepunctData#(4) x);
   DepunctData#(6) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[3] = x[2];
   outVec[4] = x[3];
   return outVec;
endfunction // Bit

// not used in wifi   
function DepunctData#(10) dp3 (DepunctData#(6) x);
   DepunctData#(10) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[3] = x[2];
   outVec[4] = x[3];
   outVec[7] = x[4];
   outVec[8] = x[5];
   return outVec;
endfunction // Bit

// Viterbi:
typedef ConvEncoderOutDataSz ViterbiInDataSz;
typedef ConvEncoderInDataSz  ViterbiOutDataSz;
typedef ConvEncoderHistSz    KSz;       // no of input bits
typedef 35                   TBLength;  // the minimum TB length for each output
typedef 5                    NoOfDecodes;    // no of traceback per stage, TBLength dividible by this value
typedef 3                    MetricSz;  // input metric
typedef 1                    FwdSteps;  // forward step per cycle
typedef 4                    FwdRadii;  // 2^(FwdRadii+FwdSteps*ConvInSz) <= 2^(KSz-1)
typedef 1                    ConvInSz;  // conv input size
typedef 2                    ConvOutSz; // conv output size

// ReedDecoder:
typedef ReedEncoderDataSz ReedDecoderDataSz;

// Decoder: (Construct from Depuncturer,Viterbifor and ReedDecoder)
typedef DepuncturerInDataSz DecoderInDataSz;
typedef ReedDecoderDataSz   DecoderOutDataSz;

// Descrambler:
typedef ScramblerDataSz    DescramblerDataSz;    
typedef ScramblerShifterSz DescramblerShifterSz;
Bit#(DescramblerShifterSz) descramblerGenPoly = scramblerGenPoly;
typedef TXScramblerCtrl    RXDescramblerCtrl;

typedef struct {
   RXDescramblerCtrl  descramblerCtrl;
   Bit#(12)           length;               
   RXGlobalCtrl       globalCtrl;
} RXDescramblerAndGlobalCtrl deriving(Eq, Bits); 

function RXDescramblerCtrl 
   descramblerMapCtrl(RXDescramblerAndGlobalCtrl ctrl);
   return ctrl.descramblerCtrl;
endfunction