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
import FIFO::*;
import FIFOF::*;
import FixedPoint::*;
import GetPut::*;
import List::*;
import UniqueWrappers::*;
import Vector::*;

// import FPComplex::*;
// import DataTypes::*;
// import CORDIC::*;
// import FixedPointLibrary::*;
// import FParams::*;
// import LibraryFunctions::*;
// import Pipeline2::*;
// import Debug::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

function Action fpcmplxVecWrite(Integer fwidth, Vector#(length,FPComplex#(i_sz,f_sz)) dataVec)
provisos(Add#(1,xxA,i_sz),
	   Add#(4,xxB,TAdd#(32,f_sz)),
	   Add#(i_sz,f_sz,TAdd#(i_sz,f_sz)));
      return joinActions(map(fpcmplxWrite(fwidth),dataVec));
endfunction // Action

function FFTData genOmega(Integer idx);
      Nat shift_sz = fromInteger(valueOf(LogFFTSz));
      FFTAngle angle = negate(fromInteger(idx)>>shift_sz);
      FFTCosSinPair omg  = getCosSinPair(angle,16);
      FFTData res = cmplx(omg.cos,omg.sin);
      return res;
endfunction

function Vector#(HalfFFTSz,FFTData) genOmegas();
      return map(genOmega, genVector);
endfunction

interface ROM#(type addr_type, type data_type);
  method data_type read(addr_type addr);
endinterface

// Addr is bigger than HalfFFTSz...XXX
(*synthesize*)
module mkOmegaROM (ROM#(FFTStep,Vector#(NoBfly,FFTData)));
   
  Vector#(LogFFTSz,Vector#(HalfFFTSz,FFTData)) omegaLong = genOmegaVecs;
  Vector#(NoFFTStep,Vector#(NoBfly,FFTData)) omegaVecs = unpack(pack(genOmegaVecs)); 

/*  for(Integer i = 0; i < valueof(LogFFTSz); i = i+1)
    begin
    for(Integer j = 0; j < valueof(HalfFFTSz); j = j+4)
       begin
         omegaVecs[i*valueof(FFTFold)+j/4] = takeAt(j,genOmegaVecs[i]);
       end
    end
*/
  method Vector#(NoBfly,FFTData) read(FFTStep addr);
    return omegaVecs[addr];
  endmethod

endmodule

function Vector#(sz,Bit#(n)) getIdxVec(Integer stage)
  provisos(Log#(sz,n));
      Integer logFFTSz = valueOf(n);
      Nat shiftSz = fromInteger(logFFTSz - stage);
      return map(leftShiftBy(shiftSz),      // shift back
		 map(rightShiftBy(shiftSz), // div
		     map(reverseBits, 
			 map(fromInteger, genVector))));      
endfunction // Vector

function Vector#(sz,FFTData) getIndVec(Vector#(sz,FFTData) inVec,
				       Integer stage);
      return map(select(inVec),getIdxVec(stage));
endfunction // Vector

(* noinline *)
function OmegaVecs genOmegaVecs();
      Vector#(LogFFTSz, Integer) iterVec = genVector;
      return map(getIndVec(genOmegas), iterVec);
endfunction

(*noinline*)
function FFTBFlyData fftRadix2Bfly(Tuple2#(FFTData,FFTBFlyData) 
				   inData);
      match {.omg, .dataVec} = inData;
      match {.i1, .i2} = dataVec;
      let newI2 = omg*i2;
      let o1 = i1 + newI2;
      let o2 = i1 - newI2;      
      return tuple2(o1,o2);
endfunction


function ActionValue#(FFTBFlyData) fftRadix2BflyCheckClipped(Tuple2#(FFTData,FFTBFlyData) 
				   inData);
      actionvalue
      match {.omg, .dataVec} = inData;
      match {.i1, .i2} = dataVec;
      FixedPoint#(FFTISz, FSz) max = maxBound;
      FixedPoint#(FFTISz, FSz) min = minBound;

      let adjustedI2 = fpcmplxMult(omg,i2);
      

      if(adjustedI2.img > fxptSignExtend(max))
        begin 
          $display("ERROR FFT CLIP TOO BIG!"); 
          $finish;
        end
      else if(adjustedI2.img < fxptSignExtend(min))
        begin 
          $display("ERROR FFT CLIP TOO SMALL!"); 
          $finish;
        end 
     
      if(adjustedI2.rel > fxptSignExtend(max))
        begin 
          $display("ERROR FFT CLIP TOO BIG!"); 
          $finish;
        end
      else if(adjustedI2.rel < fxptSignExtend(min))
        begin 
          $display("ERROR FFT CLIP TOO SMALL!"); 
          $finish;
        end 
      let newI2 = omg*i2;
      let o1 = i1 + newI2;
      let o2 = i1 - newI2;      
      return tuple2(o1,o2);
      endactionvalue
endfunction

(*noinline*)
function FFTBFlyData fftRadix2BflyClipped(Tuple2#(FFTData,FFTBFlyData) 
				   inData);
      match {.omg, .dataVec} = inData;
      match {.i1, .i2} = dataVec;
      FixedPoint#(FFTISz, FSz) max = maxBound;
      FixedPoint#(FFTISz, FSz) min = maxBound;

      let newI2 = fpcmplxMult(omg,i2);
      let adjustedI2 = newI2;

      if(adjustedI2.img > fxptSignExtend(max))
        begin 
          adjustedI2.img = fxptSignExtend(max);   
        end
      else if(adjustedI2.img < fxptSignExtend(min))
        begin 
          adjustedI2.img = fxptSignExtend(min);   
        end 
     
      if(adjustedI2.rel > fxptSignExtend(max))
        begin 
          adjustedI2.rel = fxptSignExtend(max);   
        end
      else if(adjustedI2.rel < fxptSignExtend(min))
        begin 
          adjustedI2.rel = fxptSignExtend(min);   
        end 
      let o1 = i1 + fpcmplxTruncate(adjustedI2);
      let o2 = i1 - fpcmplxTruncate(adjustedI2);      
      return tuple2(o1,o2);
endfunction

// We basically need a bunch of "no omega functions..."


function ActionValue#(FFTBflyMesg) fftBflys(FFTBflyMesg inMesg); 
    actionvalue
      let outData <- mapM(fftRadix2BflyCheckClipped, inMesg);
      if(`DEBUG_FFT > 0) 
        begin
          $write("fftO_omegas = [");
    	  fpcmplxVecWrite(4, map(tpl_1,inMesg));
          $display("];");
          $write("fftO_data = [");
          fpcmplxVecWrite(4, concat(map(tuple2Vec,map(tpl_2,inMesg))));
          $display("];");
        end

     Vector#(NoBfly,FFTData) dummyOmegas = newVector;

      if(`DEBUG_FFT > 0) 
        begin
          $write("fftO_output = [");
          fpcmplxVecWrite(4, concat(map(tuple2Vec,outData)));
          $display("];");
        end

      return zip(dummyOmegas, outData);
    endactionvalue
endfunction      


function ActionValue#(FFTBflyMesgNoOmega) fftBflysNoOmega(ROM#(FFTStep,Vector#(NoBfly,FFTData)) omegaROM, FFTBflyMesgNoOmega inMesg);
    actionvalue
      match {.stage,.step,.data} = inMesg; 
      let omegas = omegaROM.read({stage,step});

      if(`DEBUG_FFT > 0) 
        begin
          $display("stage: %d, step: %d, index: %d", stage, step, {stage,step});
          $write("fftNO_omegas[%d] = [",{stage,step});
          fpcmplxVecWrite(4, omegas);
          $display("];");
          $write("fftNO_data = [");
          fpcmplxVecWrite(4, concat(map(tuple2Vec,data)));
          $display("];");
        end

      let outData = map(fftRadix2Bfly, zip(omegas,data));

      if(`DEBUG_FFT > 0) 
        begin
          $write("fftNO_output = [");
          fpcmplxVecWrite(4, concat(map(tuple2Vec,outData)));
          $display("];");
        end

      return tuple3(stage,step,outData);
    endactionvalue
endfunction      

(* synthesize *)
module mkFFTBflys_RWire(Pipeline2#(FFTBflyMesg));
   Pipeline2#(FFTBflyMesg) pipeStage <- mkPipeStage_RWire(fftBflys);
   return pipeStage;
endmodule   


module mkFFTBflysNoOmega_RWire(Pipeline2#(FFTBflyMesgNoOmega));
   
   ROM#(FFTStep,Vector#(NoBfly,FFTData)) omegaROM <- mkOmegaROM;
   Pipeline2#(FFTBflyMesgNoOmega) pipeStage <- mkPipeStage_RWire(fftBflysNoOmega(omegaROM));
   return pipeStage;
endmodule

(* synthesize *)
module mkFFTBflys_FIFO(Pipeline2#(FFTBflyMesg));
   Pipeline2#(FFTBflyMesg) pipeStage <- mkPipeStage_FIFO(fftBflys);
   return pipeStage;
endmodule   

(* noinline *)
function FFTTupleVec fftPermute(FFTDataVec inDataVec);
      Vector#(HalfFFTSz, FFTData) fstHalfVec = take(inDataVec);
      Vector#(HalfFFTSz, FFTData) sndHalfVec = takeTail(inDataVec);
      return zip(fstHalfVec,sndHalfVec);
endfunction // FFTDataVec

(* noinline *)
function FFTDataVec fftPermuteRes(FFTDataVec inDataVec);
      Integer logFFTSz = valueOf(LogFFTSz);      
      return getIndVec(inDataVec, logFFTSz);
endfunction // FFTDataVec

function Vector#(2,a) tuple2Vec(Tuple2#(a,a) in);
      Vector#(2,a) outVec = newVector;
      outVec[0] = tpl_1(in);
      outVec[1] = tpl_2(in);
      return outVec;
endfunction // Vector

(* synthesize *)
module [Module] mkOneStage(Pipeline2#(FFTTuples));

   Pipeline2#(FFTStageMesg) stageFU;
   stageFU <- mkPipeline2_Time(mkFFTBflys_RWire); // gotta fix this bastard
   FIFO#(FFTStage) stageQ <- mkLFIFO;

   interface Put in;
      method Action put(FFTTuples inMesg);
      begin
	 let inStage = tpl_1(inMesg);
	 let inDataVec = tpl_2(inMesg);
	 let dataVec = fftPermute(inDataVec);
	 let omgs = genOmegaVecs[inStage];  
	 let inVec = zip(omgs,dataVec);
	 stageFU.in.put(inVec);
         if(`DEBUG_FFT > 0) 
           begin
             $write("fftO_stage_%d = [",inStage);
             fpcmplxVecWrite(4, concat(map(tuple2Vec,dataVec)));
             $display("];");
           end

	 stageQ.enq(inStage + 1);
      end
      endmethod
   endinterface
   
   interface Get out;
      method ActionValue#(FFTTuples) get();
	 let res <- stageFU.out.get;
         stageQ.deq;
         return tuple2(stageQ.first, concat(map(tuple2Vec, tpl_2(unzip(res)))));
      endmethod
   endinterface     
endmodule // FFTDataVec

(* synthesize *)
module [Module] mkOneStageNoOmega(Pipeline2#(FFTTuples));

   Pipeline2#(FFTStageMesgNoOmega) stageFU;
   stageFU <- mkPipeline2_TimeControl(mkFFTBflysNoOmega_RWire); // gotta fix this bastard
   FIFO#(FFTStage) stageQ <- mkLFIFO;

   interface Put in;
      method Action put(FFTTuples inMesg);
      begin
	 let inStage = tpl_1(inMesg);
	 let inDataVec = tpl_2(inMesg);
	 let dataVec = fftPermute(inDataVec);
	 //let omgs = genOmegaVecs[inStage];  // divide this one up, I suppose.
	 let inVec = tuple2(inStage,dataVec); // must determine how many folds occur
	 stageFU.in.put(inVec);

         if(`DEBUG_FFT > 0) 
           begin
             $write("fftNO_stage_%d = [",inStage);
             fpcmplxVecWrite(4, concat(map(tuple2Vec,dataVec)));
             $display("];");
           end

	 stageQ.enq(inStage + 1);
      end
      endmethod
   endinterface
   
   interface Get out;
      method ActionValue#(FFTTuples) get();
	 let res <- stageFU.out.get;
         stageQ.deq;
         match {.ctrl, .data} = res;
         return tuple2(stageQ.first, concat(map(tuple2Vec, data)));
      endmethod
   endinterface     
endmodule // FFTDataVec





