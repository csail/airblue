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
import GetPut::*;
import Vector::*;

// import ComplexLibrary::*;
// import FPComplex::*;
// import DataTypes::*;
// import CORDIC::*;
// import FixedPointLibrary::*;
// import FParams::*;
// import FFTIFFT_Library::*;
// import LibraryFunctions::*;
// import Pipeline2::*;
// import Controls::*;
// import Interfaces::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;

interface FFTIFFT;
	// input
	method Action putInput(FFTControl isIFFT, 
			       FFTDataVec fpcmplxVec);
	// output
	method ActionValue#(FFTDataVec) getOutput();
endinterface


(*synthesize*)
module [Module] mkFFTIFFTNoOmega(FFTIFFT);
   FFTStage noStages = fromInteger(valueOf(LogFFTSz)-1);
   
   // state elements
   Pipeline2#(FFTTuples) pipeline <- mkPipeline2_Circ(noStages,mkOneStageNoOmega); 

   //shrink this thing
   FIFO#(FFTControl) isIFFTQ <- mkSizedFIFO(1);// was LogFFTSz

   function FFTData shifting(FFTData inData);
   begin
      Nat shiftSz = fromInteger(valueOf(LogFFTSz));
      return cmplx(inData.rel>>shiftSz,inData.img>>shiftSz);
   end
   endfunction
   
   // methods
   method Action putInput(FFTControl isIFFT, FFTDataVec fpcmplxVec);
      if (isIFFT == IFFT)
	fpcmplxVec = map(cmplxSwap, fpcmplxVec);
      isIFFTQ.enq(isIFFT);
      pipeline.in.put(tuple2(0, fpcmplxVec));
   endmethod

   method ActionValue#(FFTDataVec) getOutput();
      let mesg <- pipeline.out.get;
      let outVec = fftPermuteRes(tpl_2(mesg));
      let isIFFT = isIFFTQ.first;
      if (isIFFT == IFFT) 
	outVec = map(cmplxSwap, map(shifting, outVec));
      isIFFTQ.deq;
      return outVec;
   endmethod
endmodule


(*synthesize*)
module [Module] mkFFTIFFT(FFTIFFT);
   FFTStage noStages = fromInteger(valueOf(LogFFTSz)-1);
   
   // state elements
   Pipeline2#(FFTTuples) pipeline <- mkPipeline2_Circ(noStages,mkOneStage); 

   //shrink this thing
   FIFO#(FFTControl) isIFFTQ <- mkSizedFIFO(1);// was LogFFTSz

   function FFTData shifting(FFTData inData);
   begin
      Nat shiftSz = fromInteger(valueOf(LogFFTSz));
      return cmplx(inData.rel>>shiftSz,inData.img>>shiftSz);
   end
   endfunction
   
   // methods
   method Action putInput(FFTControl isIFFT, FFTDataVec fpcmplxVec);
      if (isIFFT == IFFT)
	fpcmplxVec = map(cmplxSwap, fpcmplxVec);
      isIFFTQ.enq(isIFFT);
      pipeline.in.put(tuple2(0, fpcmplxVec));
   endmethod

   method ActionValue#(FFTDataVec) getOutput();
      let mesg <- pipeline.out.get;
      let outVec = fftPermuteRes(tpl_2(mesg));
      let isIFFT = isIFFTQ.first;
      if (isIFFT == IFFT) 
	outVec = map(cmplxSwap, map(shifting, outVec));
      isIFFTQ.deq;
      return outVec;
   endmethod
endmodule   


(*synthesize*)
module [Module] mkFFTIFFTOmega(FFTIFFT);
   FFTStage noStages = fromInteger(valueOf(LogFFTSz)-1);
   
   // state elements
   Pipeline2#(FFTTuples) pipeline <- mkPipeline2_Circ(noStages,mkOneStage); 

   FIFO#(FFTControl) isIFFTQ <- mkSizedFIFO(1);// was LogFFTSz;

   function FFTData shifting(FFTData inData);
   begin
      Nat shiftSz = fromInteger(valueOf(LogFFTSz));
      return cmplx(inData.rel>>shiftSz,inData.img>>shiftSz);
   end
   endfunction
   
   // methods
   method Action putInput(FFTControl isIFFT, FFTDataVec fpcmplxVec);
      if (isIFFT == IFFT)
	fpcmplxVec = map(cmplxSwap, fpcmplxVec);
      isIFFTQ.enq(isIFFT);
      pipeline.in.put(tuple2(0, fpcmplxVec));
   endmethod

   method ActionValue#(FFTDataVec) getOutput();
      let mesg <- pipeline.out.get;
      let outVec = fftPermuteRes(tpl_2(mesg));
      let isIFFT = isIFFTQ.first;
      if (isIFFT == IFFT) 
	outVec = map(cmplxSwap, map(shifting, outVec));
      isIFFTQ.deq;
      return outVec;
   endmethod
endmodule 

// CtrlFFT a control wrapper for the FFT. 		      		   
interface CtrlFFTIFFT#(type ctrl_t, 
                       numeric type n, 
                       numeric type i_prec, 
                       numeric type f_prec);
	// input
	method Action putInput(FFTControl isIFFT, FFTMesg#(ctrl_t,n,i_prec,f_prec) fftifftMesg);
	// output
	method ActionValue#(FFTMesg#(ctrl_t,n,i_prec,f_prec)) getOutput();
endinterface

module [Module] mkCtrlFFTIFFT (CtrlFFTIFFT#(ctrl_t,FFTSz,ISz,FSz))
     provisos (Bits#(ctrl_t,ctrl_sz));
   
   FFTIFFT fftifft <- mkFFTIFFT;
   FIFO#(ctrl_t) ctrlQ <- mkSizedFIFO(1);//was logFFTSz
 
   function FixedPoint#(ISz,FSz) fxptBound(FixedPoint#(FFTISz, FSz) x);
      FixedPoint#(ISz,FSz) fmax = maxBound;
      FixedPoint#(ISz,FSz) fmin = minBound;
      FixedPoint#(ISz,FSz) res = fxptTruncate(x);
      if (x > fxptSignExtend(fmax))
         res = fmax;
      else if (x < fxptSignExtend(fmin))
         res = fmin;
      return res;
   endfunction

   function FPComplex#(ISz,FSz) fpcmplxBound(FFTData x);
      return FPComplex {
         rel: fxptBound(x.rel),
         img: fxptBound(x.img)
      };
   endfunction
   
   method Action putInput(FFTControl isIFFT, FFTMesg#(ctrl_t,FFTSz,ISz,FSz) fftifftMesg);   
      fftifft.putInput(isIFFT, map(fpcmplxSignExtend,fftifftMesg.data));
      ctrlQ.enq(fftifftMesg.control);
   endmethod
  
   method ActionValue#(FFTMesg#(ctrl_t,FFTSz,ISz,FSz)) getOutput;
      let data <- fftifft.getOutput;
      ctrlQ.deq;
      return Mesg{control:ctrlQ.first,data:(map(fpcmplxBound,data))};
   endmethod

endmodule

interface DualFFTIFFT#(type fft_ctrl_t,
                       type ifft_ctrl_t, 
                       numeric type n, 
                       numeric type i_prec, 
                       numeric type f_prec);

  interface IFFT#(ifft_ctrl_t, n, i_prec, f_prec) ifft;
  interface FFT#(fft_ctrl_t, n, i_prec, f_prec) fft;
endinterface

typedef union tagged {
  fft_ctrl_t FFTCtrl;
  ifft_ctrl_t IFFTCtrl;
} DualFFTIFFTControl#(type fft_ctrl_t, type ifft_ctrl_t) deriving (Bits,Eq);

typedef 1 DualFIFODepth;

module [Module] mkDualFFTIFFT(DualFFTIFFT#(fft_ctrl_t,ifft_ctrl_t,FFTSz,ISz,FSz))
   provisos (Bits#(fft_ctrl_t,fft_ctrl_sz),
             Bits#(ifft_ctrl_t,ifft_ctrl_sz),
             Bits#(DualFFTIFFTControl#(fft_ctrl_t, ifft_ctrl_t), fftifft_sz));

   CtrlFFTIFFT#(DualFFTIFFTControl#(fft_ctrl_t,ifft_ctrl_t),FFTSz,ISz,FSz) fftUnit <- mkCtrlFFTIFFT;

   Reg#(FFTControl)  preference <- mkReg(FFT);    


   FIFOF#(FFTMesg#(fft_ctrl_t,FFTSz,ISz,FSz)) inQFFT <- mkLFIFOF;
   FIFO#(ChannelEstimatorMesg#(fft_ctrl_t,FFTSz,ISz,FSz)) outQFFT <- mkSizedFIFO(valueof(DualFIFODepth));
   // must allocate space in output buffer before issuing request or we will deadlock... 
   // This also allows us to blindly call the .getOutput method, since we're guaranteed to 
   // be able to handle the response.
   FIFOF#(Bit#(0)) fftRespTokens <- mkSizedFIFOF(valueof(DualFIFODepth));

   FIFOF#(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz)) inQIFFT <- mkLFIFOF;
   FIFO#(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz)) outQIFFT <- mkSizedFIFO(valueof(DualFIFODepth));
   FIFOF#(Bit#(0)) ifftRespTokens <- mkSizedFIFOF(valueof(DualFIFODepth));

   RWire#(FFTMesg#(DualFFTIFFTControl#(fft_ctrl_t,ifft_ctrl_t),FFTSz,ISz,FSz)) resultWire <- mkRWire; 
  
   rule putInputFFT(preference == FFT || !inQIFFT.notEmpty || !ifftRespTokens.notFull);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual FFT input");
            for(Integer i=0; i<valueOf(FFTSz) ; i=i+1)
                  begin
                     Int#(TAdd#(ISz,FSz)) img = unpack(pack(inQFFT.first.data[i].img));
                     Int#(TAdd#(ISz,FSz)) rel = unpack(pack(inQFFT.first.data[i].rel));
                     $display("FFTIn:%d:%d:%d",i,rel,img);
                  end 
         end
      

      preference <= IFFT;
      inQFFT.deq;
      fftRespTokens.enq(?);
      fftUnit.putInput(FFT,Mesg{control: tagged FFTCtrl (inQFFT.first.control), data: inQFFT.first.data});
   endrule
   
   rule putInputIFFT(preference == IFFT || !inQFFT.notEmpty || !fftRespTokens.notFull);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual IFFT input");
         end
      
      preference <= FFT;
      inQIFFT.deq;
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(inQIFFT.first.data);
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(inQIFFT.first.data);
      let data = append(sndHalfVec,fstHalfVec);
      ifftRespTokens.enq(?);
      fftUnit.putInput(IFFT,Mesg{control: tagged IFFTCtrl (inQIFFT.first.control), data: data});
   endrule
 
   
   rule getOutput(True);
       if(`DEBUG_FFT == 1)
         begin
            $display("Dual deq @ %d", $time);
         end
      
      let mesg <- fftUnit.getOutput;
      resultWire.wset(mesg);
   endrule


   rule getOutputFFT(resultWire.wget matches tagged Valid .result &&& result.control matches tagged FFTCtrl .ctrl);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual deq fft @ %d", $time);
         end
      
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(result.data);
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(result.data);
      let data = append(sndHalfVec,fstHalfVec);
      outQFFT.enq(Mesg{control:ctrl,data:data});
   endrule

   rule getOutputIFFT(resultWire.wget matches tagged Valid .result &&& result.control matches tagged IFFTCtrl .ctrl);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual deq ifft @ %d", $time);
         end
      
      outQIFFT.enq(Mesg{control:ctrl,data:result.data});
   endrule
	       
   interface airblue_types::IFFT ifft;
     interface in = fifoToPut(fifofToFifo(inQIFFT));
     interface Get out;
       method ActionValue#(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz)) get();
          if(`DEBUG_FFT == 1)
             begin
                $display("Dual IFFT output");   
             end
                
         ifftRespTokens.deq;
         outQIFFT.deq;
         return outQIFFT.first;
       endmethod
     endinterface
   endinterface

   interface airblue_types::FFT fft;
     interface in = fifoToPut(fifofToFifo(inQFFT));
     interface Get out;
       method ActionValue#(FFTMesg#(fft_ctrl_t,FFTSz,ISz,FSz)) get();
          if(`DEBUG_FFT == 1)
             begin
                $display("Dual FFT output");   
             end
          
         fftRespTokens.deq;
         outQFFT.deq;
         return outQFFT.first;
       endmethod
     endinterface     
   endinterface
endmodule

//typedef union tagged {
//  fft_ctrl_t FFTCtrl;
//  ifft_ctrl_t IFFTCtrl;
//} DualFFTIFFTControl#(type fft_ctrl_t, type ifft_ctrl_t) deriving (Bits,Eq);

// this module ditches area by using a simple roundrobin protocol to select input
module [Module] mkDualFFTIFFTRR(DualFFTIFFT#(fft_ctrl_t,ifft_ctrl_t,FFTSz,ISz,FSz))
   provisos (Bits#(fft_ctrl_t,fft_ctrl_sz),
             Bits#(ifft_ctrl_t,ifft_ctrl_sz),
             Bits#(DualFFTIFFTControl#(fft_ctrl_t, ifft_ctrl_t), fftifft_sz));

   CtrlFFTIFFT#(DualFFTIFFTControl#(fft_ctrl_t,ifft_ctrl_t),FFTSz,ISz,FSz) fftUnit <- mkCtrlFFTIFFT;

   Reg#(FFTControl)  preference <- mkReg(FFT);    

   FIFO#(ChannelEstimatorMesg#(fft_ctrl_t,FFTSz,ISz,FSz)) outQFFT <- mkSizedFIFO(valueof(DualFIFODepth));
   // must allocate space in output buffer before issuing request or we will deadlock... 
   // This also allows us to blindly call the .getOutput method, since we're guaranteed to 
   // be able to handle the response.
   FIFOF#(Bit#(0)) fftRespTokens <- mkSizedFIFOF(valueof(DualFIFODepth));


   FIFO#(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz)) outQIFFT <- mkSizedFIFO(valueof(DualFIFODepth));
   FIFOF#(Bit#(0)) ifftRespTokens <- mkSizedFIFOF(valueof(DualFIFODepth));

   RWire#(FFTMesg#(DualFFTIFFTControl#(fft_ctrl_t,ifft_ctrl_t),FFTSz,ISz,FSz)) resultWire <- mkRWire; 
  
   
   rule getOutput(True);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual deq @ %d", $time);
         end
      
      let mesg <- fftUnit.getOutput;
      resultWire.wset(mesg);
   endrule


   rule getOutputFFT(resultWire.wget matches tagged Valid .result &&& result.control matches tagged FFTCtrl .ctrl);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual deq fft @ %d", $time);
         end
      
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(result.data);
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(result.data);
      let data = append(sndHalfVec,fstHalfVec);
      outQFFT.enq(Mesg{control:ctrl,data:data});
   endrule

   rule getOutputIFFT(resultWire.wget matches tagged Valid .result &&& result.control matches tagged IFFTCtrl .ctrl);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual deq ifft @ %d", $time);
         end
      
      outQIFFT.enq(Mesg{control:ctrl,data:result.data});
   endrule

   rule alterPreference;
     preference <= (preference == IFFT)?FFT:IFFT;
   endrule
	       
   interface airblue_types::IFFT ifft;
     
     interface Put in;
         method Action put(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz) mesg) if(preference == IFFT );
            if(`DEBUG_FFT == 1)
               begin
                  $display("Dual IFFT input");           
               end
            
           Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(mesg.data);
           Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(mesg.data);
           let data = append(sndHalfVec,fstHalfVec);
           ifftRespTokens.enq(?);
           fftUnit.putInput(IFFT,Mesg{control: tagged IFFTCtrl (mesg.control), data: data});
         endmethod
     endinterface

     interface Get out;
       method ActionValue#(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz)) get();
          if(`DEBUG_FFT == 1)
             begin
                $display("Dual IFFT output");   
             end
          
         ifftRespTokens.deq;
         outQIFFT.deq;
         return outQIFFT.first;
       endmethod
     endinterface
   endinterface

   interface airblue_types::FFT fft;
   
     interface Put in;
         method Action put(FFTMesg#(fft_ctrl_t,FFTSz,ISz,FSz) mesg) if(preference == FFT);
            if(`DEBUG_FFT == 1)
               begin
                  $display("Dual FFT input");
                  for(Integer i=0; i<valueOf(FFTSz) ; i=i+1)
                  begin
                     Int#(TAdd#(ISz,FSz)) img = unpack(pack(mesg.data[i].img));
                     Int#(TAdd#(ISz,FSz)) rel = unpack(pack(mesg.data[i].rel));
                     $display("FFTIn:%d:%d:%d",i,rel,img);
                  end                       
               end
            
           fftRespTokens.enq(?);
           fftUnit.putInput(FFT,Mesg{control: tagged FFTCtrl (mesg.control), data: mesg.data});
         endmethod
     endinterface

     interface Get out;
       method ActionValue#(FFTMesg#(fft_ctrl_t,FFTSz,ISz,FSz)) get();
          if(`DEBUG_FFT == 1)
             begin
                $display("Dual FFT output");   
             end
          
         fftRespTokens.deq;
         outQFFT.deq;
         return outQFFT.first;
       endmethod
     endinterface     
   endinterface
endmodule



module [Module] mkIFFT(airblue_types::IFFT#(ctrl_t,FFTSz,ISz,FSz))
   provisos (Bits#(ctrl_t,ctrl_sz));
   
   CtrlFFTIFFT#(ctrl_t,FFTSz,ISz,FSz) ifft <- mkCtrlFFTIFFT;
   FIFO#(IFFTMesg#(ctrl_t,FFTSz,ISz,FSz)) inQ <- mkLFIFO;
   FIFO#(CPInsertMesg#(ctrl_t,FFTSz,ISz,FSz)) outQ <- mkSizedFIFO(2);
   FIFO#(Bit#(0)) reservationFIFO <- mkSizedFIFO(2);   
   
   // rule
   rule putInput(True);
      let mesg = inQ.first;
      inQ.deq;
      reservationFIFO.enq(?);
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(mesg.data);
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(mesg.data);
      let data = append(sndHalfVec,fstHalfVec);
      ifft.putInput(IFFT,Mesg{control:mesg.control,data: data});     
   endrule
   
   rule getOutput(True);
      let mesg <- ifft.getOutput;
      outQ.enq(mesg);
   endrule
	       
   // methods
   interface in = fifoToPut(inQ);
   interface Get out;
     method ActionValue#(CPInsertMesg#(ctrl_t,FFTSz,ISz,FSz)) get;
       reservationFIFO.deq;
       outQ.deq;
       return outQ.first;
     endmethod
   endinterface
endmodule

module [Module] mkFFT(airblue_types::FFT#(ctrl_t,FFTSz,ISz,FSz))
   provisos (Bits#(ctrl_t,ctrl_sz));
   
   CtrlFFTIFFT#(ctrl_t,FFTSz,ISz,FSz) fft <- mkCtrlFFTIFFT;
   FIFO#(FFTMesg#(ctrl_t,FFTSz,ISz,FSz)) inQ <- mkLFIFO;
   FIFO#(ChannelEstimatorMesg#(ctrl_t,FFTSz,ISz,FSz)) outQ <- mkSizedFIFO(2);   
   FIFO#(Bit#(0)) reservationFIFO <- mkSizedFIFO(2);   

   // rule
   rule putInput(True);
      reservationFIFO.enq(?);
      inQ.deq;
      fft.putInput(FFT,inQ.first);
   endrule
   
   rule getOutput(True);
      let mesg <- fft.getOutput;
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(mesg.data);
      Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(mesg.data);
      let data = append(sndHalfVec,fstHalfVec);
      outQ.enq(Mesg{control:mesg.control,data:data});
   endrule
	       
   // methods
   interface in = fifoToPut(inQ);
   interface Get out;
     method ActionValue#(ChannelEstimatorMesg#(ctrl_t,FFTSz,ISz,FSz)) get;
       reservationFIFO.deq;
       outQ.deq;
       return outQ.first;
     endmethod
   endinterface
endmodule

// this module ditches area by using a simple roundrobin protocol to select input
// May want to change this since anticpated usuage model is either long strings of FFT/IFFT
module [Module] mkDualFFTIFFTSharedIO(DualFFTIFFT#(fft_ctrl_t,ifft_ctrl_t,FFTSz,ISz,FSz))
   provisos (Bits#(fft_ctrl_t,fft_ctrl_sz),
             Bits#(ifft_ctrl_t,ifft_ctrl_sz),
             Bits#(DualFFTIFFTControl#(fft_ctrl_t, ifft_ctrl_t), fftifft_sz));

   CtrlFFTIFFT#(DualFFTIFFTControl#(fft_ctrl_t,ifft_ctrl_t),FFTSz,ISz,FSz) fftUnit <- mkCtrlFFTIFFT;

   FIFO#(FFTMesg#(DualFFTIFFTControl#(fft_ctrl_t,ifft_ctrl_t),FFTSz,ISz,FSz)) outQ <- mkSizedFIFO(valueof(DualFIFODepth));
   // must allocate space in output buffer before issuing request or we will deadlock... 
   // This also allows us to blindly call the .getOutput method, since we're guaranteed to 
   // be able to handle the response.
   FIFOF#(Bit#(0)) respTokens <- mkSizedFIFOF(valueof(DualFIFODepth));

   rule getOutput(True);
      if(`DEBUG_FFT == 1)
         begin
            $display("Dual deq @ %d", $time);
         end
      
      let mesg <- fftUnit.getOutput;
      outQ.enq(mesg);
   endrule

   interface airblue_types::IFFT ifft;
     
     interface Put in;
         method Action put(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz) mesg);
            if(`DEBUG_FFT == 1)
               begin
                  $display("Dual IFFT input");           
               end
            
           Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(mesg.data);
           Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(mesg.data);
           let data = append(sndHalfVec,fstHalfVec);
           respTokens.enq(?);
           fftUnit.putInput(IFFT,Mesg{control: tagged IFFTCtrl (mesg.control), data: data});
         endmethod
     endinterface

     interface Get out;
       method ActionValue#(FFTMesg#(ifft_ctrl_t,FFTSz,ISz,FSz)) get() if(outQ.first.control matches tagged IFFTCtrl .ctrl);
          if(`DEBUG_FFT == 1)
             begin
                $display("Dual IFFT output");   
             end
          
         respTokens.deq;
         outQ.deq;
         return Mesg{control: ctrl, data:outQ.first.data};
       endmethod
     endinterface
   endinterface

   interface airblue_types::FFT fft;
   
     interface Put in;
         method Action put(FFTMesg#(fft_ctrl_t,FFTSz,ISz,FSz) mesg);
            if(`DEBUG_FFT == 1)
               begin
                  $display("Dual FFT input");                      
                  for(Integer i=0; i<valueOf(FFTSz) ; i=i+1)
                  begin
                     Int#(TAdd#(ISz,FSz)) img = unpack(pack(mesg.data[i].img));
                     Int#(TAdd#(ISz,FSz)) rel = unpack(pack(mesg.data[i].rel));
                     $display("FFTIn:%d:%d:%d",i,rel,img);
                  end 
               end
            
           respTokens.enq(?);
           fftUnit.putInput(FFT,Mesg{control: tagged FFTCtrl (mesg.control), data: mesg.data});
         endmethod
     endinterface

     interface Get out;
       method ActionValue#(FFTMesg#(fft_ctrl_t,FFTSz,ISz,FSz)) get() if(outQ.first.control matches tagged FFTCtrl .ctrl);
          if(`DEBUG_FFT == 1)
             begin
                $display("Dual FFT output");   
             end
          
         respTokens.deq;
         outQ.deq;
         Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) fstHalfVec = take(outQ.first.data);
         Vector#(HalfFFTSz,FPComplex#(ISz,FSz)) sndHalfVec = takeTail(outQ.first.data);
         let data = append(sndHalfVec,fstHalfVec);
         return Mesg{control:ctrl,data:data};
       endmethod
     endinterface     
   endinterface
endmodule

