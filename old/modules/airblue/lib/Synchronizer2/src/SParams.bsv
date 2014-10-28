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

import Complex::*;
import FixedPoint::*;
import Vector::*;

// import FPComplex::*;
// import ProtocolParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"

//  ////////////////////////////////////////
//  // Synchronizer parameters (changable)
//  ////////////////////////////////////////

//  // specific for OFDM specification
//  typedef 16  SSLen;        // short symbol length (auto correlation delay 16)

//  typedef 64  LSLen;        // long symbol length (auto correlation delay 64)

//  typedef 160 LSStart;      // when the long symbol start

//  typedef 320 SignalStart;  // when the signal (useful data) start

//  typedef 80  SymbolLen;    // one symbol length

//  typedef 64  NoCPLen;      // symbol length after removing CP

//  // implementation parameters 
//  typedef 96  SSyncPos;      // short symbol synchronization position, also start gain adjustment ( 2*SSLen <= this value < GHoldPos < LBStart-FreqMesnLen)

//  typedef 128 GHoldPos;      // position fixing gain (ghold) (GHoldPos + FreqMeanLen < LSStart) 

//  typedef 224 LSyncPos;      // long symbol synchronization position  ( LSStart <= this value < SinglaStart)       

//  typedef 2   SyncIntPrec;   // number of integer bits for internal arithmetic

//  typedef 14  SyncFractPrec; // number of fractional bits for internal arithmetic 

//  typedef 16  FreqMeanLen;   // how many samples we collect to calculate CFO (power of 2, at most 32, bigger == more tolerant to noise)

//  typedef 480 TimeResetPos;  // reset time if coarCounter is larger than this, must be bigger than SignalStart

//  typedef 2   CORDICPipe;    // number of pipeline stage of the cordic

//  typedef 16  CORDICIter;    // number of cordic iterations (max 16 iterations, must be multiple of CORDICPIPE)


//////////////////////////////////////////////////
// Types automatic defined by parameters
/////////////////////////////////////////////////

// for all
typedef TLog#(TimeResetPos)                          CounterSz;
typedef TAdd#(TMul#(2,SyncIntPrec),1)                MulIntPrec;

// types for auto-correlator
typedef TSub#(LSLen, SSLen)                          LSLSSLen;              // LSLen - SSLen
typedef TSub#(TAdd#(SSLen, SSLen),1)                 CoarTimeCorrPos;       // first pos to able detect high correlation
typedef TAdd#(TSub#(SSyncPos, CoarTimeCorrPos),1)    CoarTimeAccumDelaySz;  //
typedef TAdd#(TLog#(SSLen), MulIntPrec)              CoarTimeAccumIntPrec;  // int precision
typedef TAdd#(TMul#(2,CoarTimeAccumIntPrec),1)       CoarTimeCorrIntPrec;   // int precision for power and correlation square
typedef TAdd#(SyncFractPrec,SyncFractPrec)           CoarTimeCorrFractPrec; // fract precision for power and coorelation square
typedef TLog#(TAdd#(CoarTimeAccumDelaySz,1))         CoarTimeAccumIdx;      // no of bit to hold the accumulated value

// types for fine time estimator
typedef TSub#(LSyncPos, LSStart)                     FineTimeCorrDelaySz;   // no of element to delay
typedef TAdd#(FineTimeCorrDelaySz, 1)                FineTimeCorrSz;        // no of element to cross correlate
// for single bit cross correlation
typedef TAdd#(TLog#(FineTimeCorrSz), 3)              FineTimeCorrResSz;     // the type for corr result 
typedef TAdd#(1,TMul#(2,FineTimeCorrResSz))          FineTimeCorrFullResSz; // 
// for cross correlation
typedef 1                                            FineTimeIntPrec;
typedef 7                                            FineTimeFractPrec;
typedef FPComplex#(FineTimeIntPrec,FineTimeFractPrec) FineTimeType;
typedef TAdd#(TLog#(FineTimeCorrSz),TAdd#(TMul#(FineTimeIntPrec,2),1)) FineTimeCorrIntPrec;
typedef TAdd#(FineTimeFractPrec,FineTimeFractPrec)   FineTimeCorrFractPrec;
//typedef TAdd#(TLog#(FineTimeCorrSz),3) FineTimeCorrIntPrec;
//typedef 14                             FineTimeCorrFractPrec;
typedef FPComplex#(FineTimeCorrIntPrec,
                   FineTimeCorrFractPrec)            FineTimeCorrType;
typedef FixedPoint#(TAdd#(TMul#(FineTimeCorrIntPrec,2),1),
                    TMul#(FineTimeCorrFractPrec,2))  FineTimeCorrPowType; 

typedef TAdd#(TLog#(LSLen), MulIntPrec)              CorrIntPrec;

// Freq. Offset Estimator
typedef TLog#(FreqMeanLen)                           FreqMeanLenIdxSz;
typedef TAdd#(FreqMeanLenIdxSz, 1)                   FreqOffAccumIntPrec;
typedef TLog#(SymbolLen)                             RotAngCounterSz;
typedef TAdd#(FreqMeanLenIdxSz,TLog#(SSLen))         CoarFreqOffAccumRShift;
typedef TAdd#(FreqMeanLenIdxSz,TLog#(LSLen))         FineFreqOffAccumRShift;

typedef 24 BigFractPrec;

typedef FPComplex#(SyncIntPrec, SyncFractPrec)           Sample;
typedef FPComplex#(MulIntPrec, SyncFractPrec)            Product;
typedef FixedPoint#(MulIntPrec, SyncFractPrec)           Magnitude;
typedef FPComplex#(CoarTimeAccumIntPrec, SyncFractPrec)  Correlation;
typedef FixedPoint#(CoarTimeAccumIntPrec, SyncFractPrec) MagnitudeSum;
typedef FPComplex#(CorrIntPrec, SyncFractPrec)           LongCorrelation;
typedef FixedPoint#(1, SyncFractPrec)                    FreqAngle;

// high pass filter alpha =  1 / (1 + 2*pi*f/F) where f = cutoff freq and F = sampling freq
FPComplex#(SyncIntPrec,SyncFractPrec) hpf_alpha = cmplx(fromRational(99376,100000),0);  
