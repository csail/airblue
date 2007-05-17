import Complex::*;
import FixedPoint::*;
import Vector::*;

import ofdm_parameters::*;
import ofdm_common::*;
import ofdm_types::*;
import ofdm_base::*;
import ofdm_arith_library::*;

// import Parameters::*;

// from parameters file
typedef FFTIFFTSz      FFTSz;
typedef TXFPIPrec        ISz;
typedef TXFPFPrec        FSz;
typedef FFTIFFTNoBfly NoBfly;

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
typedef Vector#(HalfFFTSz, FFTBFlyData)                FFTTupleVec;
typedef Vector#(NoBfly, Tuple2#(FFTData,FFTBFlyData))  FFTBflyMesg;
typedef Tuple2#(FFTStage, FFTDataVec)                  FFTTuples;
typedef Vector#(HalfFFTSz, Tuple2#(FFTData,FFTBFlyData)) FFTStageMesg;






