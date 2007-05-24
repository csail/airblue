// WiFi 802.11a Parameters
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
   R0,  // 6Mbps
   R1,  // 9Mbps
   R2,  // 12Mbps
   R3,  // 18Mbps
   R4,  // 24Mbps
   R5,  // 36Mbps
   R6,  // 48Mbps
   R7   // 54Mbps
} Rate deriving(Eq, Bits);

typedef struct {
    Bool firstSymbol;
    Rate rate;
} TXGlobalCtrl deriving(Eq, Bits);


typedef `FPIPrec TXFPIPrec; // tx fixedpoint integer precision
typedef `FPFPrec TXFPFPrec; // tx fixedpoint fractional precision

typedef `FPIPrec RXFPIPrec; // rx fixedpoint integer precision
typedef `FPFPrec RXFPFPrec; // rx fixedpoint fractional precision
typedef TXGlobalCtrl RXGlobalCtrl; // same as tx

// Local Parameters:

// Scrambler:
typedef `ScramblerDataSz ScramblerDataSz;    
typedef  7 ScramblerShifterSz;
Bit#(ScramblerShifterSz) scramblerGenPoly = `ScramblerGenPoly;
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

// Conv. Encoder:
typedef ScramblerDataSz ConvEncoderInDataSz;
typedef TMul#(2,ConvEncoderInDataSz) ConvEncoderOutDataSz;
typedef  7 ConvEncoderHistSz;
Bit#(ConvEncoderHistSz) convEncoderG1 = `ConvGenPoly1;
Bit#(ConvEncoderHistSz) convEncoderG2 = `ConvGenPoly2;

// Puncturer:
typedef ConvEncoderOutDataSz        PuncturerInDataSz;
typedef `PuncturerOutDataSz         PuncturerOutDataSz;
//typedef TMul#(2,PuncturerInDataSz)  PuncturerInBufSz;  // to be safe 2x inDataSz
//typedef TMul#(2,PuncturerOutDataSz) PuncturerOutBufSz; // to be safe 2x outDataSz 
typedef TAdd#(PuncturerInDataSz,10)                PuncturerInBufSz;
typedef TAdd#(PuncturerInBufSz,PuncturerOutDataSz) PuncturerOutBufSz; 
//typedef TDiv#(PuncturerInDataSz,4)  PuncturerF1Sz; // no. of 2/3 in parallel
//typedef TDiv#(PuncturerInDataSz,6)  PuncturerF2Sz; // no. of 3/4 in parallel
//typedef TDiv#(PuncturerInDataSz,10) PuncturerF3Sz; // no. of 5/6 in parallel
typedef 1  PuncturerF1Sz; // no. of 2/3 in parallel
typedef 1  PuncturerF2Sz; // no. of 3/4 in parallel
typedef 1  PuncturerF3Sz; // no. of 5/6 in parallel

function Bit#(3) puncturerF1 (Bit#(4) x);
   return x[2:0];
endfunction // Bit
   
function Bit#(4) puncturerF2 (Bit#(6) x);
   return {x[5],x[2:0]};
endfunction // Bit

// not used in WiFi   
function Bit#(6) puncturerF3 (Bit#(10) x);
   return 0;
endfunction // Bit

function PuncturerCtrl puncturerMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: Half;
	     R1: ThreeFourth;
	     R2: Half;
	     R3: ThreeFourth;
	     R4: Half;
	     R5: ThreeFourth;
	     R6: TwoThird;
	     R7: ThreeFourth;
	  endcase; // case(rate)
endfunction // Bit  

// Encoder: (Construct from ConvEncoder & Puncturer for wifi)
typedef ConvEncoderInDataSz EncoderInDataSz;
typedef PuncturerOutDataSz  EncoderOutDataSz;

// Interleaver:
typedef PuncturerOutDataSz  InterleaverDataSz;
typedef 48                  MinNcbps;

// used for both interleaver, mapper
function Modulation modulationMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: BPSK;
	     R1: BPSK;
	     R2: QPSK;
	     R3: QPSK;
	     R4: QAM_16;
	     R5: QAM_16;
	     R6: QAM_64;
	     R7: QAM_64;
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
   Integer i = (ncbps/16) * (k%16) + k/16;
   Integer f = (i/s); // expect floor
   Integer j = s*f + (i + ncbps - (16*i/ncbps))%s;
   return (k >= ncbps) ? k : j;
endfunction

//Mapper:
typedef InterleaverDataSz MapperInDataSz;
typedef 48                MapperOutDataSz;
Bool mapperNegateInput = False;

//Pilot:
typedef  MapperOutDataSz  PilotInDataSz;
typedef  64               PilotOutDataSz;
typedef   7               PilotPRBSSz;
Bit#(PilotPRBSSz) pilotPRBSMask = 'b1001000;
Bit#(PilotPRBSSz) pilotInitSeq  = 'b1111111;

function PilotInsertCtrl pilotMapCtrl(TXGlobalCtrl ctrl);
   return ctrl.firstSymbol ? PilotRst : PilotNorm;
endfunction 

function Symbol#(PilotOutDataSz,TXFPIPrec,TXFPFPrec) 
   pilotAdder(Symbol#(PilotInDataSz,TXFPIPrec,TXFPFPrec) x,
	      Bit#(1) ppv);
   
   Integer i =0, j = 0;
   // assume all guards initially
   Symbol#(PilotOutDataSz,TXFPIPrec,TXFPFPrec) syms = replicate(cmplx(0,0));
   
   // data subcarriers
   for(i = 6; i < 11; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 12; i < 25; i = i + 1, j = j + 1)
      syms[i] = x[j]; 
   for(i = 26; i < 32 ; i = i + 1, j = j + 1)
      syms[i] = x[j];  
   for(i = 33; i < 39 ; i = i + 1, j = j + 1)
      syms[i] = x[j];   
   for(i = 40; i < 53 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 54; i < 59 ; i = i + 1, j = j + 1)
      syms[i] = x[j];

   //pilot subcarriers
   syms[11] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[25] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[39] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[53] = mapBPSK(True,  ppv); // map 0 to -1, 1 to 1
   
   return syms;
endfunction

// FFT/IFFT:
typedef PilotOutDataSz FFTIFFTSz;
typedef `FFTIFFTNoBfly FFTIFFTNoBfly;

// CPInsert:
typedef FFTIFFTSz CPInsertDataSz;

function CPInsertCtrl cpInsertMapCtrl(TXGlobalCtrl ctrl);
   let fstEle = ctrl.firstSymbol ? SendBoth : SendNone;
   return tuple2(fstEle, CP0);
endfunction

// Synchronizer:
// specific for OFDM specification
typedef 16  SSLen;        // short symbol length (auto correlation delay 16)
typedef 64  LSLen;        // long symbol length (auto correlation delay 64)
typedef 160 LSStart;      // when the long symbol start
typedef 320 SignalStart;  // when the signal (useful data) start
typedef 80  SymbolLen;    // one symbol length
// implementation parameters
typedef `SSyncPos  SSyncPos;      // short symbol synchronization position ( 2*SSLen <= this value < LBStart)
typedef `LSyncPos  LSyncPos;      // long symbol synchronization position  ( LSStart <= this value < SinglaStart)       
typedef 16  FreqMeanLen;          // how many samples we collect to calculate CFO (power of 2, at most 32, bigger == more tolerant to noise)
typedef 480 TimeResetPos;         // reset time if coarCounter is larger than this, must be bigger than SignalStart
typedef `CORDICPipe   CORDICPipe; // number of pipeline stage of the cordic
typedef `CORDICIter   CORDICIter; // number of cordic iterations (max 16 iterations, must be multiple of CORDICPIPE)
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
  
   // data subcarriers
   for(i = 6; i < 11; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 12; i < 25; i = i + 1, j = j + 1)
      syms[j] = x[i]; 
   for(i = 26; i < 32 ; i = i + 1, j = j + 1)
      syms[j] = x[i];  
   for(i = 33; i < 39 ; i = i + 1, j = j + 1)
      syms[j] = x[i];   
   for(i = 40; i < 53 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 54; i < 59 ; i = i + 1, j = j + 1)
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
   Integer i = s*f + (j + (16*j/ncbps))%s;
   Integer k = 16*i-(ncbps-1)*(16*i/ncbps);
   return (j >= ncbps) ? j : k;
endfunction			  

// Depuncturer:
typedef DeinterleaverDataSz            DepuncturerInDataSz;
typedef PuncturerInDataSz              DepuncturerOutDataSz;
typedef TAdd#(DepuncturerInDataSz,6)                  DepuncturerInBufSz;  // to be safe 2x inDataSz
typedef TAdd#(DepuncturerInBufSz,DepuncturerOutDataSz) DepuncturerOutBufSz; // to be safe 2x outDataSz 
//typedef TMul#(2,DepuncturerInDataSz)   DepuncturerInBufSz;  // to be safe 2x inDataSz
//typedef TMul#(2,DepuncturerOutDataSz)  DepuncturerOutBufSz; // to be safe 2x outDataSz 
// typedef TDiv#(DepuncturerOutDataSz,4)  DepuncturerF1Sz;     // no. of 2/3 in parallel
// typedef TMul#(DepuncturerF1Sz,3)       DepuncturerF1InSz;   
// typedef TMul#(DepuncturerF1Sz,4)       DepuncturerF1OutSz;
// typedef TDiv#(DepuncturerOutDataSz,6)  DepuncturerF2Sz;     // no. of 3/4 in parallel
// typedef TMul#(DepuncturerF2Sz,4)       DepuncturerF2InSz;   
// typedef TMul#(DepuncturerF2Sz,6)       DepuncturerF2OutSz;
// typedef TDiv#(DepuncturerOutDataSz,10) DepuncturerF3Sz;     // no. of 5/6 in parallel
// typedef TMul#(DepuncturerF3Sz,6)       DepuncturerF3InSz;   
// typedef TMul#(DepuncturerF3Sz,10)      DepuncturerF3OutSz;
typedef 1  DepuncturerF1Sz;     // no. of 2/3 in parallel
typedef 3  DepuncturerF1InSz;   
typedef 4  DepuncturerF1OutSz;
typedef 1  DepuncturerF2Sz;     // no. of 3/4 in parallel
typedef 4  DepuncturerF2InSz;   
typedef 6  DepuncturerF2OutSz;
typedef 1  DepuncturerF3Sz;     // no. of 5/6 in parallel
typedef 6  DepuncturerF3InSz;   
typedef 10 DepuncturerF3OutSz;

function DepunctData#(4) dp1 (DepunctData#(3) x);
   DepunctData#(4) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[2] = x[2];
   return outVec;
endfunction // Bit
   
function DepunctData#(6) dp2 (DepunctData#(4) x);
   DepunctData#(6) outVec = replicate(4);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[2] = x[2];
   outVec[5] = x[3];
   return outVec;
endfunction // Bit

// not used in wifi   
function DepunctData#(10) dp3 (DepunctData#(6) x);
   DepunctData#(10) outVec = replicate(4);
   return outVec;
endfunction // Bit

// Viterbi:
typedef ConvEncoderOutDataSz ViterbiInDataSz;
typedef ConvEncoderInDataSz  ViterbiOutDataSz;
typedef ConvEncoderHistSz    KSz;       // no of input bits
typedef `TBLength            TBLength;  // the minimum TB length for each output
typedef `NoOfDecodes         NoOfDecodes;    // no of traceback per stage, TBLength dividible by this value
typedef 3                    MetricSz;  // input metric
typedef 1                    FwdSteps;  // forward step per cycle
typedef `FwdRadii            FwdRadii;  // 2^(FwdRadii+FwdSteps*ConvInSz) <= 2^(KSz-1)
typedef 1                    ConvInSz;  // conv input size
typedef 2                    ConvOutSz; // conv output size

// Decoder: (Construct from Depuncturer and Viterbifor wifi)
typedef DepuncturerInDataSz DecoderInDataSz;
typedef ViterbiOutDataSz    DecoderOutDataSz;

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
