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

// import CORDIC::*;
// import DataTypes::*;
// import FPComplex::*;
import ProtocolParameters::*;
import FFTParameters::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
//`include "asim/provides/airblue_parameters.bsh"

// from parameters file
typedef FFTIFFTSz      FFTSz;
typedef TXFPIPrec        ISz;
typedef TXFPFPrec        FSz;
typedef FFTIFFTNoBfly NoBfly;

//tag definitions
typedef enum {
  FFT,
  IFFT
} FFTControl deriving (Bits,Eq);

// derived parameters
typedef TLog#(FFTSz)                                   LogFFTSz;
typedef TAdd#(LogFFTSz,1)                              LogFFTSzP1;
typedef TDiv#(FFTSz,2)                                 HalfFFTSz;
typedef TLog#(HalfFFTSz)                               LogHalfFFTSz;
typedef TAdd#(LogFFTSzP1,ISz)                          FFTISz;
typedef FixedPoint#(FFTISz, FSz)                       FFTAngle;
typedef FixedPoint#(1,FSz)                             CORDICAngle;
typedef CosSinPair#(FFTISz, FSz)                       FFTCosSinPair;
typedef FPComplex#(FFTISz, FSz)                        FFTData;
typedef Vector#(FFTSz,FPComplex#(ISz,FSz))             FPComplexVec;
typedef Vector#(FFTSz,FFTData)	                       FFTDataVec;
typedef Vector#(LogFFTSz,Vector#(HalfFFTSz,FFTData))   OmegaVecs;
typedef Tuple2#(FFTData,FFTData)                       FFTBFlyData;
typedef Bit#(TLog#(LogFFTSz))                          FFTStage;
typedef Bit#(TLog#(TDiv#(HalfFFTSz,NoBfly)))           FFTFoldNum;
typedef TMul#(TDiv#(HalfFFTSz,NoBfly),LogFFTSz)        NoFFTStep;   
typedef TDiv#(HalfFFTSz,NoBfly)                        FFTFold;
typedef Bit#(TLog#(NoFFTStep))                         FFTStep;
typedef Vector#(HalfFFTSz, FFTBFlyData)                FFTTupleVec;
typedef Vector#(NoBfly, Tuple2#(FFTData,FFTBFlyData))  FFTBflyMesg;
typedef Tuple2#(FFTStage, FFTDataVec)                  FFTTuples;
typedef Vector#(HalfFFTSz, Tuple2#(FFTData,FFTBFlyData)) FFTStageMesg;
typedef Tuple2#(FFTStage,Vector#(HalfFFTSz, FFTBFlyData)) FFTStageMesgNoOmega;

// derived parameters for drilling through Omega values
typedef Tuple3#(FFTStage,FFTFoldNum,Vector#(NoBfly, FFTBFlyData))  FFTBflyMesgNoOmega;





