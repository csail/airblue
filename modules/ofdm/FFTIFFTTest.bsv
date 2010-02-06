import Connectable::*;
import Complex::*;
import FPComplex::*;
import DataTypes::*;
import CORDIC::*;
import FixedPoint::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import FParams::*;
import FFTIFFT_Library::*;
import GetPut::*;
import FFTIFFT::*;
import RandomGen::*;

function Action fpcmplxVecWrite(Integer fwidth, FFTDataVec dataVec);
      return joinActions(map(fpcmplxWrite(fwidth),dataVec));
endfunction // Action

// (* synthesize *)
module mkFFTIFFTTest(Empty);

   RandomGen#(64)     randGen <- mkMersenneTwister(64'hB573AE980FF1134C);
   FFTIFFT            fft     <- mkFFTIFFT;
   FFTIFFT            ifft    <- mkFFTIFFT;
   Reg#(FFTDataVec)   dataVec <- mkReg(replicate(0));
   Reg#(Bit#(16))     putfftCnt  <- mkReg(0);
   Reg#(Bit#(16))     putifftCnt <- mkReg(0);
   Reg#(Bit#(16))     getifftCnt <- mkReg(0);  
   Reg#(Bit#(32))     cycle <- mkReg(0);

   rule putFFT(True);
      let randData <- randGen.genRand;
      FPComplex#(2,14) newfpcmplx = unpack(randData[31:0]);
      let newDataVec = shiftInAt0(dataVec, 
	                          fpcmplxSignExtend(newfpcmplx));
      dataVec <= newDataVec;
      putfftCnt <= putfftCnt + 1;
      fft.putInput(False, dataVec);
      $write("fft_in_%h = [",putfftCnt);
      fpcmplxVecWrite(4, dataVec);
      $display("];");
   endrule

   rule putIFFT(True);
      let mesg <- fft.getOutput;
      putifftCnt <= putifftCnt + 1;
      ifft.putInput(True, mesg);	
      $write("fft_out_%h = [",putifftCnt);
      fpcmplxVecWrite(4, mesg);
      $display("];");
   endrule


   rule getIFFT(True);
      let mesg <- ifft.getOutput;
      getifftCnt <= getifftCnt + 1;
      $write("ifft_out_%h = [",getifftCnt);
      fpcmplxVecWrite(4, mesg);
      $display("];");
      if (getifftCnt == 1024)
	$finish(0);
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      $display("cycle: %d",cycle);
   endrule
   
endmodule // mkFFTTest




