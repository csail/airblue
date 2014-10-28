import Complex::*;
import Connectable::*;
import FIFO::*;
import FIFOF::*;
import FixedPoint::*;
import FShow::*;
import GetPut::*;
import Vector::*;

// import FPComplex::*;
// import DataTypes::*;
// import CORDIC::*;
// import FParams::*;
// import FFTIFFT_Library::*;
// import FFTIFFT::*;
// import RandomGen::*;
// import Interfaces::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_fft.bsh"


(* synthesize *) 
module mkTestDual (DualFFTIFFT#(Bit#(0),Bit#(0),FFTSz,ISz,FSz));
  let m <- mkDualFFTIFFTRR;
  return m;
endmodule 

(* synthesize *) 
module mkTestShared (DualFFTIFFT#(Bit#(0),Bit#(0),FFTSz,ISz,FSz));
  let m <- mkDualFFTIFFTSharedIO;
  return m;
endmodule 

(* synthesize *)
module mkTestIFFTFull (IFFT#(Bit#(0),FFTSz,ISz,FSz));
  let m <- mkIFFT;
  return m;
endmodule

(* synthesize *)
module mkTestFFTFull (FFT#(Bit#(0),FFTSz,ISz,FSz));
  let m <- mkFFT;
  return m;
endmodule

