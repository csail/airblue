//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

// WiFi 802.11a Parameters
//import Controls::*;
import Vector::*;
//import FPComplex::*;
//import LibraryFunctions::*;
import Complex::*;
//import DataTypes::*;
//import Interfaces::*;
import GetPut::*;
import Connectable::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;

// print out detailed debug information?
Bool detailedDebugInfo = False;

//PhyLength variable was not defined previously
typedef Bit#(12) PhyPacketLength;
typedef Bit#(8)  PhyData;
typedef Vector#(8,Bit#(8)) PhyHints;

instance FShow#(PhyPacketLength);
   function Fmt fshow (PhyPacketLength length);
      return $format("%d",length);
   endfunction
endinstance

instance FShow#(Rate);
   function Fmt fshow (Rate rate);
     case (rate)
       R0: return $format("6Mbps");
       R1: return $format("9Mbps");
       R2: return $format("12Mbps");
       R3: return $format("18Mbps");
       R4: return $format("24Mbps");
       R5: return $format("36Mbps");
       R6: return $format("48Mbps");
       R7: return $format("54Mbps");
       default: return $format("Rate Unknown");
     endcase
   endfunction
endinstance

// Global Parameters:
typedef enum {
   R0 = 0,  // 6Mbps
   R1 = 1,  // 9Mbps
   R2 = 2,  // 12Mbps
   R3 = 3,  // 18Mbps
   R4 = 4,  // 24Mbps
   R5 = 5,  // 36Mbps
   R6 = 6,  // 48Mbps
   R7 = 7  // 54Mbps
} Rate deriving(Eq, Bits);

typedef struct {
    Bool firstSymbol;
    Rate rate;
} TXGlobalCtrl deriving(Eq, Bits);

instance IsEncoderCtrl#(TXGlobalCtrl);
   function Bool isFirstMesg(TXGlobalCtrl ctrl);
      return ctrl.firstSymbol;
   endfunction
endinstance

typedef 4  TXFPIPrec; // tx fixedpoint integer precision
typedef 14 TXFPFPrec; // tx fixedpoint fractional precision

typedef 4  RXFPIPrec; // rx fixedpoint integer precision
typedef 14 RXFPFPrec; // rx fixedpoint fractional precision

typedef struct {
   Bool firstSymbol; 
   Bool updatePilot; // need to update pilot? 
   Bool viterbiPushZeros; // viterbi needs to push zeros to clear all data out  
   Rate rate;
} RXGlobalCtrl deriving(Eq, Bits);
          
instance FShow#(RXGlobalCtrl);
  function Fmt fshow(RXGlobalCtrl ctrl);
    return $format(" RXGlobalCtrl: firstSymbol: ") + fshow(ctrl.firstSymbol) + $format(" updatePilot: ") + fshow(ctrl.updatePilot) + $format(" viterbiPushZeros ") + fshow(ctrl.viterbiPushZeros) + $format(" Rate: ") + fshow(ctrl.rate);
  endfunction
endinstance

// Local Parameters:

// Scrambler:
typedef 12 ScramblerDataSz;    
typedef  7 ScramblerShifterSz;
Bit#(ScramblerShifterSz) magicConstantDecoderSeed = 'b1001010;
Bit#(ScramblerShifterSz) magicConstantSeed = 'b0000101;
Bit#(ScramblerShifterSz) scramblerGenPoly = 'b1001000;
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
typedef 1                                                    ConvInSz;  // conv input size
typedef 2                                                    ConvOutSz; // conv output size
typedef 12                                                   ConvEncoderInDataSz;
typedef TDiv#(TMul#(ConvOutSz,ConvEncoderInDataSz),ConvInSz) ConvEncoderOutDataSz; // ConvOutSz * ConvEncoderInDataSz must be dividable by ConvInSz
typedef 7                                                    ConvEncoderHistSz; // k

function Vector#(ConvOutSz,Bit#(ConvEncoderHistSz)) genConvPolys;
   Vector#(ConvOutSz,Bit#(ConvEncoderHistSz)) convPolys = newVector();
   convPolys[0] = 'b1011011;
   convPolys[1] = 'b1111001;
   return convPolys;
endfunction

Vector#(ConvOutSz,Bit#(ConvEncoderHistSz))                   convEncoderPolys = genConvPolys;
Bit#(ConvEncoderHistSz) convEncoderG1 = convEncoderPolys[0];
Bit#(ConvEncoderHistSz) convEncoderG2 = convEncoderPolys[1];

// Puncturer:
typedef ConvEncoderOutDataSz        PuncturerInDataSz;
typedef 24                          PuncturerOutDataSz;
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
   Integer min_ncbps = valueOf(MinNcbps);
   Integer ncbps = min_ncbps;
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
   // for channel allocation
   Integer h = min_ncbps/3; // divide the data subcarriers into 3 subgroups
   Integer i = (ncbps/h) * (k%h) + k/h;
   Integer f = (i/s); // expect floor
   Integer j = s*f + (i + ncbps - (h*i/ncbps))%s;
   return (k >= ncbps) ? k : j;
endfunction

// These functions are used to determine the length of a packet
// refactor at some point
function Integer bitsPerSymbol(Rate rate);
   Integer min_ncbps = valueOf(MinNcbps);
   case (rate)
      R0: return min_ncbps/2;   // bpsk(*1), half(*1/2)
      R1: return min_ncbps*3/4; // bpsk(*1), threefourth(*3/4)
      R2: return min_ncbps;     // qpsk(*2), half(*1/2)
      R3: return min_ncbps*3/2; // qpsk(*2), threefourth(*3/4)
      R4: return min_ncbps*2;   // 16 qam(*4), half(*1/2)
      R5: return min_ncbps*3;   // 16 qam(*4), threefourth(*3/4)
      R6: return min_ncbps*4;   // 64 qam(*6), twothird(*2/3)
      R7: return min_ncbps*9/2; // 64 qam(*6), threefourth(*3/4)
      default: return min_ncbps/2;
   endcase 
endfunction


//Mapper:
typedef InterleaverDataSz MapperInDataSz;
//typedef 48                MapperOutDataSz;
typedef MinNcbps            MapperOutDataSz; // modify for channel allocation
Bool mapperNegateInput = True;

//Pilot:
typedef  MapperOutDataSz  PilotInDataSz;
typedef  64               PilotOutDataSz; 
typedef   7               PilotPRBSSz; // pilot LFSR size
typedef   4               PilotNo;     // no. pilot subcarriers
Bit#(PilotPRBSSz) pilotPRBSMask = 'b1001000; // LFSR mask
Bit#(PilotPRBSSz) pilotInitSeq  = 'b1111111; // initial LFSR value

function Vector#(PilotNo,Integer) getPilotLocs();
   Vector#(PilotNo,Integer) pilot_locs = newVector(); //pilot subcarrier locations
   pilot_locs[0] = 11;
   pilot_locs[1] = 25;
   pilot_locs[2] = 39;
   pilot_locs[3] = 53;
   return pilot_locs;
endfunction

function Vector#(PilotNo,Bool) getPilotIsInverseMaps();
   Vector#(PilotNo,Bool) pilot_maps = newVector(); //pilot subcarrier locations
   pilot_maps[0] = False; // map 1 to -1, 0 to 1
   pilot_maps[1] = False; // map 1 to -1, 0 to 1
   pilot_maps[2] = False; // map 1 to -1, 0 to 1
   pilot_maps[3] = True;  // map 0 to -1, 1 to 1
   return pilot_maps;
endfunction

function PilotInsertCtrl pilotMapCtrl(TXGlobalCtrl ctrl);
   return ctrl.firstSymbol ? PilotRst : PilotNorm;
endfunction 

// function Integer inversePilotMapping(Integer index);
//  Integer retVal = 0;
//   case(index)
//     0: retVal = 5;
//     1: retVal = 7;
//     2: retVal = 9;
//     3: retVal = 13;
//     4: retVal = 15;
//     5: retVal = 17;
//     6: retVal = 19;
//     7: retVal = 21;
//     8: retVal = 23;
//     9: retVal = 27;
//    10: retVal = 29;
//    11: retVal = 31;
//    12: retVal = 33;
//    13: retVal = 35;
//    14: retVal = 37;
//    15: retVal = 41;
//    16: retVal = 43;
//    17: retVal = 45;
//    18: retVal = 47;
//    19: retVal = 49;    
//    20: retVal = 51;
//    21: retVal = 55;
//    22: retVal = 57;
//    23: retVal = 59;
//   endcase
//  return retVal; 
// endfunction

function Integer inversePilotMapping(Integer index);
 Integer retVal = 0;
  case(index)
    0: retVal = 6;
    1: retVal = 7;
    2: retVal = 8;
    3: retVal = 9;
    4: retVal = 10;
    5: retVal = 12;
    6: retVal = 13;
    7: retVal = 14;
    8: retVal = 15;
    9: retVal = 16;
   10: retVal = 17;
   11: retVal = 18;
   12: retVal = 19;
   13: retVal = 20;
   14: retVal = 21;
   15: retVal = 22;
   16: retVal = 23;
   17: retVal = 24;
   18: retVal = 26;
   19: retVal = 27;    
   20: retVal = 28;
   21: retVal = 29;
   22: retVal = 30;
   23: retVal = 31;
   24: retVal = 33;
   25: retVal = 34;
   26: retVal = 35;
   27: retVal = 36;
   28: retVal = 37;  
   29: retVal = 38;
   30: retVal = 40;
   31: retVal = 41;
   32: retVal = 42;
   33: retVal = 43;
   34: retVal = 44;
   35: retVal = 45;
   36: retVal = 46;
   37: retVal = 47;
   38: retVal = 48;  
   39: retVal = 49;
   40: retVal = 50;
   41: retVal = 51;
   42: retVal = 52;
   43: retVal = 54;
   44: retVal = 55;
   45: retVal = 56;
   46: retVal = 57;
   47: retVal = 58;
  endcase
 return retVal; 
endfunction


function Symbol#(PilotOutDataSz,TXFPIPrec,TXFPFPrec) 
   pilotAdder(Symbol#(PilotInDataSz,TXFPIPrec,TXFPFPrec) x,
	      Bit#(1) ppv);
   
   Integer i =0, j = 0;
   Vector#(PilotNo,Integer) pilot_locs = getPilotLocs;
   Vector#(PilotNo,Bool)    pilot_maps = getPilotIsInverseMaps;
   // assume all guards initially
   Symbol#(PilotOutDataSz,TXFPIPrec,TXFPFPrec) syms = replicate(cmplx(0,0));
   
   // data subcarriers
   for(i = 0; i < valueOf(PilotInDataSz); i = i + 1)
      syms[inversePilotMapping(i)] = x[i];
           
   //pilot subcarriers
   for(j = 0; j < valueOf(PilotNo); j = j + 1)
      syms[pilot_locs[j]] = mapBPSK(pilot_maps[j], ppv);
   
   return syms;
endfunction

// FFT/IFFT:
typedef PilotOutDataSz FFTIFFTSz;
//typedef 4             FFTIFFTNoBfly;

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
typedef 64  SSyncPos;      // short symbol synchronization position, also start gain adjustment ( 2*SSLen <= this value < GHoldPos < LBStart-FreqMesnLen)
typedef 128 GHoldPos;      // position fixing gain (ghold) (GHoldPos + FreqMeanLen < LSStart) 
typedef 191 LSyncPos;      // long symbol synchronization position  ( LSStart <= this value < SignalStart)       
typedef 16  FreqMeanLen;   // how many samples we collect to calculate CFO (power of 2, at most 32, bigger == more tolerant to noise)
typedef 480 TimeResetPos;  // reset time if coarCounter is larger than this, must be bigger than SignalStart
typedef 2   CORDICPipe;    // number of pipeline stage of the cordic
typedef 16  CORDICIter;    // number of cordic iterations (max 16 iterations, must be multiple of CORDICPIPE)
typedef RXFPIPrec  SyncIntPrec;   // number of integer bits for internal arithmetic
typedef RXFPFPrec  SyncFractPrec; // number of fractional bits for internal arithmetic 

// Unserializer:
typedef FFTIFFTSz  UnserialOutDataSz;

// ChannelEstimator:
typedef UnserialOutDataSz  CEstInDataSz;
typedef PilotInDataSz      CEstOutDataSz;

function Tuple2#(Bool,Bool) resetPilot (Bool ctrl);
   return tuple2(ctrl,True);
endfunction

function Vector#(CEstOutDataSz,elem_t) 
   removePilotsAndGuards (Vector#(CEstInDataSz,elem_t) x);

   Integer i =0, j = 0;
   // assume all guards initially
   Vector#(CEstOutDataSz,elem_t) syms   = newVector();
  
   // data subcarriers
   for(i = 0; i < valueOf(CEstOutDataSz); i = i + 1)
      syms[i] = x[inversePilotMapping(i)];
      
   return syms;
endfunction

function Tuple2#(Vector#(PilotNo,elem_t),
                 Vector#(CEstOutDataSz,elem_t)) 
   pilotRemover (Vector#(CEstInDataSz,elem_t) x,
                 Bit#(1) ppv)
   provisos (Arith#(elem_t));
   Integer i =0;
   Vector#(PilotNo,Integer)      pilot_locs = getPilotLocs;
   Vector#(PilotNo,Bool)         pilot_maps = getPilotIsInverseMaps;
   // assume all guards initially
   Vector#(PilotNo,elem_t)       pilots = newVector();
   Vector#(CEstOutDataSz,elem_t) syms   = removePilotsAndGuards(x);
     
   //pilot subcarriers
   for(i = 0; i < valueOf(PilotNo); i = i + 1)
      pilots[i] = (ppv != pack(pilot_maps[i])) ? x[pilot_locs[i]] : negate(x[pilot_locs[i]]); 
   
   return tuple2(pilots,syms);
endfunction

// used for both deinterleaver, demapper
function Modulation demodulationMapCtrl(RXGlobalCtrl ctrl);
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

// Demapper:
typedef CEstOutDataSz  DemapperInDataSz;
typedef MapperInDataSz DemapperOutDataSz;

Bool demapperNegateOutput = mapperNegateInput;

// Deinterleaver:
typedef DemapperOutDataSz DeinterleaverDataSz;

function Integer deinterleaverGetIndex(Modulation m, Integer j);
   Integer s = 1;  
   Integer min_ncbps = valueOf(MinNcbps);
   Integer ncbps = min_ncbps;
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
   // for channel allocation
   Integer h = min_ncbps/3; // divide subcarriers into 3 subgroups
   Integer f = (j/s);
   Integer i = s*f + (j + (h*j/ncbps))%s;
   Integer k = h*i-(ncbps-1)*(h*i/ncbps);
   return (j >= ncbps) ? j : k;
//    Integer f = (j/s);
//    Integer i = s*f + (j + (16*j/ncbps))%s;
//    Integer k = 16*i-(ncbps-1)*(16*i/ncbps);
//    return (j >= ncbps) ? j : k;
endfunction			  

// Depuncturer:
typedef DemapperOutDataSz              DepuncturerInDataSz;
typedef PuncturerInDataSz              DepuncturerOutDataSz;
typedef TMul#(2,DepuncturerInDataSz)   DepuncturerInBufSz;  // to be safe 2x inDataSz
typedef TMul#(2,DepuncturerOutDataSz)  DepuncturerOutBufSz; // to be safe 2x outDataSz 
// typedef TDiv#(DepuncturerOutDataSz,4)  DepuncturerF1Sz;     // no. of 2/3 in parallel
// typedef TMul#(DepuncturerF1Sz,3)       DepuncturerF1InSz;   
// typedef TMul#(DepuncturerF1Sz,4)       DepuncturerF1OutSz;
// typedef TDiv#(DepuncturerOutBufSz,6)   DepuncturerF2Sz;     // no. of 3/4 in parallel
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
   DepunctData#(4) outVec = replicate(0);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[2] = x[2];
   return outVec;
endfunction // Bit
   
function DepunctData#(6) dp2 (DepunctData#(4) x);
   DepunctData#(6) outVec = replicate(0);
   outVec[0] = x[0];
   outVec[1] = x[1];
   outVec[2] = x[2];
   outVec[5] = x[3];
   return outVec;
endfunction // Bit

// not used in wifi   
function DepunctData#(10) dp3 (DepunctData#(6) x);
   DepunctData#(10) outVec = replicate(0);
   return outVec;
endfunction // Bit

// depuncturerMapCtrl
function PuncturerCtrl depuncturerMapCtrl(RXGlobalCtrl ctrl);
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

// Viterbi:
typedef ConvEncoderOutDataSz ViterbiInDataSz;
typedef ConvEncoderInDataSz  ViterbiOutDataSz;
typedef ConvEncoderHistSz    KSz;       // no of input bits
// the following parameters now at ViterbiParameters.bsv
// typedef 48                   TBLength;  // the minimum TB length for each output
// typedef 4                    NoOfDecodes;    // no of traceback per stage, TBLength dividible by this value
// typedef 3                    MetricSz;  // input metric
// typedef 1                    FwdSteps;  // forward step per cycle
// typedef 5                    FwdRadii;  // 2^(FwdRadii+FwdSteps*ConvInSz) <= 2^(KSz-1)

// viterbiMapCtrl
function Bool viterbiMapCtrl(RXGlobalCtrl ctrl);
   return ctrl.viterbiPushZeros;
endfunction

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

// typedef struct {
//    RXDescramblerCtrl  descramblerCtrl;
//    RXGlobalCtrl       globalCtrl;
// } RXDescramblerAndGlobalCtrl deriving(Eq, Bits); 

// function RXDescramblerCtrl 
//    descramblerMapCtrl(RXDescramblerAndGlobalCtrl ctrl);
//    return ctrl.descramblerCtrl;
// endfunction

// function Bit#(0) 
//    descramblerConvertCtrl(RXDescramblerAndGlobalCtrl ctrl);
//     return ?;
// endfunction


// for rx controller 
