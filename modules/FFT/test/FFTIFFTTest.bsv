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
import Connectable::*;
import FIFO::*;
import FIFOF::*;
import FixedPoint::*;
import FShow::*;
import GetPut::*;
import Vector::*;
import StmtFSM::*;

import Pipe::*;

// import FPComplex::*;
// import DataTypes::*;
// import CORDIC::*;
import FParams::*;
import FFTIFFT_Library::*;
import FFTIFFTTestLib::*;
import FFTIFFT::*;
// import Interfaces::*;
import FFTInterface::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
//`include "asim/provides/airblue_fft.bsh"
//`include "asim/provides/airblue_parameters.bsh"
//`include "asim/provides/airblue_fft_library.bsh"


// import "BDPI" function Action generateFFTValues(int fftSize, int realBitSize, int imagBitSize);
// import "BDPI" function ActionValue#(FixedPoint#(16,16)) getRealInput(int index);
// import "BDPI" function ActionValue#(Bool) checkRealResult(int index, int result);
// import "BDPI" function ActionValue#(FixedPoint#(16,16)) getImagInput(int index);
// import "BDPI" function ActionValue#(Bool) checkImagResult(int index, int result);
// import "BDPI" function Action freeLast();

module mkFFTRequest#(FFTIndication indication)(FFTRequest);
   
   //FFTIFFT            fft     <- mkFFTIFFT;
   //FFTIFFT            ifft    <- mkFFTIFFT;
   IFFT#(Bit#(0),FFTSz,ISz,FSz) ifftFull <- mkTestIFFTFull;
   FFT#(Bit#(0),FFTSz,ISz,FSz) fftFull <- mkTestFFTFull;
   //DualFFTIFFT#(Bit#(0),Bit#(0), FFTSz,ISz,FSz) fftShared <- mkTestShared;
   //DualFFTIFFT#(Bit#(0),Bit#(0),FFTSz,ISz,FSz) ifftShared <- mkTestShared;
   DualFFTIFFT#(Bit#(0),Bit#(0),FFTSz,ISz,FSz) dualFFTIFFT <- mkTestDual;
   FIFO#(FFTDataVec)  fftInValue   <- mkSizedFIFO(100); // 100 was chosen somewhat 
                                                        // arbitrarily.
   FIFO#(FFTDataVec) expectedResult <- mkFIFO;

   Reg#(Bit#(16))     putfftCnt  <- mkReg(0);
   Reg#(Bit#(16))     putifftCnt <- mkReg(0);
   Reg#(Bit#(16))     getifftCnt <- mkReg(0);  
   Reg#(Bit#(32))     cycle <- mkReg(0);
   let tempFIFO <- mkFIFO;

   let fsm = seq
		$display("Attempting to generatFFT values\n");
		// use1 for ISz so as no to make things
		indication.generateFFTValues(fromInteger(valueof(FFTSz)),1,16);
	     endseq;

   FIFOF#(Complex#(FixedPoint#(16,16))) inputFifo <- mkFIFOF();
   PipeOut#(Complex#(FixedPoint#(16,16))) inputPipe = toPipeOut(inputFifo);
   function FPComplex#(FFTISz,FSz) toFpComplex(Complex#(FixedPoint#(16,16)) in);
      return Complex { rel: fxptTruncate(in.rel), img: fxptTruncate(in.rel) };
   endfunction
   PipeOut#(Vector#(1,FPComplex#(FFTISz,FSz))) newDataElementPipe = mapPipe(replicate, mapPipe(toFpComplex, inputPipe));
   PipeOut#(Vector#(FFTSz, FPComplex#(FFTISz,FSz))) newDataVecPipe <- mkUnfunnel(newDataElementPipe);

   rule putInputData;
      // need to scale down fp value
      FFTDataVec newDataVec <- toGet(newDataVecPipe).get();

      fftInValue.enq(newDataVec);
      putfftCnt <= putfftCnt + 1;
      
      
      FFTMesg#(Bit#(0),FFTSz,ISz,FSz) dualMesg = Mesg{control: 0, data:  map(fpcmplxTruncate,newDataVec)};
      dualFFTIFFT.fft.in.put(dualMesg);
      fftFull.in.put(dualMesg);
      //fftShared.fft.in.put(dualMesg);
      $write("fft_in_%d = [",putfftCnt);
      fpcmplxVecWrite(4, newDataVec);
      $display("];");
      $write("fft_in_%d = [",putfftCnt);
      fpcmplxVecWrite(4, dualMesg.data );
      $display("];");
   endrule

   rule putIFFT(True);
      //let mesg <- fft.getOutput;
      putifftCnt <= putifftCnt + 1;
      
      let dualMesg <- dualFFTIFFT.fft.out.get;
      tempFIFO.enq(dualMesg);
   endrule

   PipeOut#(FFTMesg#(Bit#(0),FFTSz,ISz,FSz)) fftFullOutPipe <- mkPipeOut(fftFull.out.get);
   Vector#(2, PipeOut#(FFTMesg#(Bit#(0),FFTSz,ISz,FSz))) fftFullOutPipes <- mkForkVector(fftFullOutPipe);
   function Vector#(FFTSz,FPComplex#(ISz,FSz)) fftMesgData(FFTMesg#(Bit#(0),FFTSz,ISz,FSz) in);
      return in.data;
   endfunction
   function Vector#(n,Tuple2#(Bit#(TLog#(n)),a)) indexElts(Vector#(n,a) vec);
      function Tuple2#(Bit#(TLog#(n)),a) indexElt(Integer i);
	 return tuple2(fromInteger(i), vec[i]);
      endfunction
      return genWith(indexElt);
   endfunction
   PipeOut#(Vector#(FFTSz,Tuple2#(Bit#(TLog#(FFTSz)),FPComplex#(ISz,FSz)))) fftOutDataPipe = mapPipe(indexElts, mapPipe(fftMesgData, fftFullOutPipes[0]));
   PipeOut#(Tuple2#(Bit#(TLog#(FFTSz)),FPComplex#(ISz,FSz))) fftOutElementsPipe <- mkFunnel1(fftOutDataPipe);

   rule checkFftFull;
      let pair <- toGet(fftOutElementsPipe).get();
      let i = tpl_1(pair);
      let cx = tpl_2(pair);
      FixedPoint#(16,16) rel = fxptSignExtend(cx.rel);
      FixedPoint#(16,16) img = fxptSignExtend(cx.img);
      indication.checkOutput(extend(i),unpack(pack(rel)),unpack(pack(img)));
      //FIXME
      //indication.freeLast();
   endrule

   rule putIfftFullIn;
      let fftMesg <- toGet(fftFullOutPipes[1]).get();
      ifftFull.in.put(fftMesg);
   endrule

   rule putIFFTrR;
     tempFIFO.deq;
     dualFFTIFFT.ifft.in.put(tempFIFO.first);     
   endrule

   rule getIFFT(True);
      fftInValue.deq;
     
      let dualMesg <- dualFFTIFFT.ifft.out.get;
      Vector#(FFTSz,FPComplex#(FFTISz,FSz)) dualMesgExt = map(fpcmplxSignExtend,dualMesg.data);
      let ifftMesg <- ifftFull.out.get;
      Vector#(FFTSz,FPComplex#(FFTISz,FSz)) ifftMesgExt = map(fpcmplxSignExtend,ifftMesg.data);
      //let ifftSharedMesg <- ifftShared.ifft.out.get;
      //Vector#(64,FPComplex#(FFTISz,FSz)) ifftSharedMesgExt = map(fpcmplxSignExtend,ifftSharedMesg.data);

      Vector#(2,Vector#(FFTSz,FPComplex#(FFTISz,FSz))) mesgData = newVector();
      
      mesgData[1] = dualMesgExt;
      mesgData[0] = ifftMesgExt;
      getifftCnt <= getifftCnt + 1;
      $write("ifft_out_%d [",getifftCnt);

      // Compare results
      Bool finishNow = False;
      // FIXME: rewrite so it does not take so much static elaboration. -jamey
      // for(Integer j =0 ; j < 2; j=j+1)
      //   begin
      //     for( Integer i = 0; i < valueof(FFTSz);i=i+1) 
      //      begin
      //       // have to check the real/imag independently. 255 works
      //       if((fftInValue.first[i].rel > 155*epsilon + mesgData[j][i].rel) ||
      //          (fftInValue.first[i].rel < mesgData[j][i].rel - 155*epsilon) ||
      //          (fftInValue.first[i].img > 155*epsilon + mesgData[j][i].img) ||
      //          (fftInValue.first[i].img < mesgData[j][i].img - 155*epsilon ))
      //         begin
      //           $write("FFT mismatch: ");
      //           fpcmplxWrite(5,fftInValue.first[i]);
      //           fpcmplxWrite(5,mesgData[j][i]);
      //           $display("");
      //           finishNow = True;
      //         end
      //     end
      //   end
     
      if(finishNow) 
        begin
          $finish;
        end

        fpcmplxVecWrite(4, dualMesgExt);
        $display("];");
        //$display("Count: %d", getifftCnt);
        if (getifftCnt == 1024)
          begin
            $display("PASS");
            $finish(0);
          end
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      $display("cycle: %d",cycle);
   endrule
   

   method Action putInput(FixedPoint#(16,16) rv, FixedPoint#(16,16) iv);
      inputFifo.enq(Complex { rel: rv, img: iv });
   endmethod
endmodule
