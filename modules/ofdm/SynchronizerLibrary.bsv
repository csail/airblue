import Complex::*;
import FIFOF::*;
import FixedPoint::*;
import Vector::*;

import ofdm_common::*;
import ofdm_parameters::*;
import ofdm_synchronizer_params::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import ComplexLibrary::*;
// import CORDIC::*;
// import DataTypes::*;
// import FixedPointLibrary::*;
// import FPComplex::*;
// import ShiftRegs::*;
// import Vector::*;

// import Parameters::*;

// convert FPComplex to single bit complex
function Complex#(Bit#(1)) toSingleBitCmplx(FPComplex#(ai,af) a)
  provisos (Add#(1,x,ai), Add#(ai,af,TAdd#(ai,af)));
      return cmplx(pack(a.rel < 0), pack(a.img < 0));
endfunction // Complex

// for single bit multiply, treat 1 = -1, 0 = +1
function Bit#(2) singleBitMult(Bit#(1) x, Bit#(1) y);
      return {x^y,1};
endfunction

// for complex single bit multiply
function Complex#(Bit#(3)) singleBitCmplxMult(Complex#(Bit#(1)) a, Complex#(Bit#(1)) b);
      let rel = signExtend(singleBitMult(a.rel, b.rel)) - signExtend(singleBitMult(a.img, b.img));
      let img = signExtend(singleBitMult(a.rel, b.img)) + signExtend(singleBitMult(a.img, b.rel));
      return cmplx(rel, img);
endfunction

// for complex single bit conj
function Complex#(Bit#(1)) singleBitCmplxConj(Complex#(Bit#(1)) a);
      return cmplx(a.rel, invert(a.img));
endfunction // Complex

// for complex single bit multiply
function Complex#(Bit#(rsz)) cmplxSignExtend(Complex#(Bit#(asz)) a)
  provisos (Add#(xxA,asz,rsz));
      let rel = signExtend(a.rel);
      let img = signExtend(a.img);
      return cmplx(rel, img);
endfunction // Complex

// for complex modulus = rel^2 + img^2, ri = 2ai + 1, rf = 2af
function Bit#(ri)  cmplxModSq(Complex#(Bit#(ai)) a)
  provisos (Add#(ai,ai,ci), Add#(1,ci,ri), Add#(xxA,ai,ri));
      return ((signExtend(a.rel) * signExtend(a.rel))  + (signExtend(a.img) * signExtend(a.img)));
endfunction // FixedPoint

// single bit cross correlation
function Complex#(Bit#(TAdd#(logn,3))) singleBitCrossCorrelation(Vector#(n, Complex#(Bit#(1))) v1, Vector#(n, Complex#(Bit#(1))) v2)
  provisos (Log#(n,logn), Add#(logn,3,TAdd#(logn,3)), Add#(1,xxA,n));
      Vector#(n, Complex#(Bit#(1))) v2Conj = Vector::map(singleBitCmplxConj, v2);
      Vector#(n, Complex#(Bit#(3))) multV = Vector::zipWith(singleBitCmplxMult, v1, v2Conj);
      Vector#(n, Complex#(Bit#(TAdd#(logn,3)))) extendedResultV = Vector::map(cmplxSignExtend, multV);
      Complex#(Bit#(TAdd#(logn,3))) result = Vector::fold(\+ ,extendedResultV); //build a binary tree structure
      return result;
endfunction // Complex	          

// complex conjugate
function Complex#(a) cmplxConj(Complex#(a) x)
  provisos (Arith#(a));
      return cmplx(x.rel, negate(x.img));
endfunction // Complex

// for fixedpoint complex multiplication 
function FPComplex#(ri,rf) fpcmplxMult(FPComplex#(ai,af) a, FPComplex#(bi,bf) b)
        provisos (Add#(ai,bi,ci),  Add#(af,bf,rf), Add#(TAdd#(ai,af), TAdd#(bi,bf), TAdd#(ci,rf)), 
		  Arith#(FixedPoint#(ri,rf)), Add#(1,ci,ri), Add#(1, TAdd#(ci,rf), TAdd#(ri,rf)));
      let rel = fxptSignExtend(fxptMult(a.rel, b.rel)) - fxptSignExtend(fxptMult(a.img, b.img));
      let img = fxptSignExtend(fxptMult(a.rel, b.img)) + fxptSignExtend(fxptMult(a.img, b.rel));
      return cmplx(rel, img);
endfunction // Complex

//for fixedpoint complex signextend
function FPComplex#(ri,rf) fpcmplxSignExtend(FPComplex#(ai,af) a)
  provisos (Add#(xxA,ai,ri), Add#(fdiff,af,rf), Add#(xxC,TAdd#(ai,af),TAdd#(ri,rf)));
      return cmplx(fxptSignExtend(a.rel), fxptSignExtend(a.img));
endfunction // Complex

//for fixedpoint complex truncate
function FPComplex#(ri,rf) fpcmplxTruncate(FPComplex#(ai,af) a)
  provisos (Add#(xxA,ri,ai), Add#(xxB,rf,af), Add#(xxC,TAdd#(ri,rf),TAdd#(ai,af)));
      return cmplx(fxptTruncate(a.rel), fxptTruncate(a.img));
endfunction // Complex

// for fixedpoint complex modulus = rel^2 + img^2, ri = 2ai + 1, rf = 2af
function FixedPoint#(ri,rf)  fpcmplxModSq(FPComplex#(ai,af) a)
  provisos (Add#(ai,ai,ci), Add#(af,af,rf), Add#(TAdd#(ai,af), TAdd#(ai,af), TAdd#(ci,rf)),
	    Arith#(FixedPoint#(ri,rf)), Add#(1,ci,ri), Add#(1, TAdd#(ci,rf), TAdd#(ri,rf)));
      return (fxptSignExtend(fxptMult(a.rel, a.rel)) + fxptSignExtend(fxptMult(a.img, a.img)));
endfunction // FixedPoint

// generic function for cross correlation
function FPComplex#(TAdd#(logn,ri),rf) crossCorrelation(Vector#(n, FPComplex#(vi,vf)) v1, Vector#(n, FPComplex#(vi,vf)) v2)
  provisos (Add#(vi,vi,xi), Add#(vf,vf,rf), Add#(TAdd#(vi,vf), TAdd#(vi,vf),TAdd#(xi,rf)),
	    Arith#(FixedPoint#(vi,vf)), Arith#(FixedPoint#(ri,rf)), 
	    Add#(1,xi,ri), Add#(1,TAdd#(xi,rf),TAdd#(ri,rf)), Log#(n,logn),
	    Add#(xxA,ri,TAdd#(logn,ri)), Add#(xxC,TAdd#(ri,rf),TAdd#(TAdd#(logn,ri),rf)),
	    Add#(1,yy,n),Arith#(FPComplex#(TAdd#(logn,ri),rf))
	    );
      Vector#(n, FPComplex#(vi,vf)) v2Conj = Vector::map(cmplxConj, v2);
      Vector#(n, FPComplex#(ri,rf)) multV = Vector::zipWith(fpcmplxMult, v1, v2Conj);
      Vector#(n, FPComplex#(TAdd#(logn,ri),rf)) extendedResultV = Vector::map(fpcmplxSignExtend, multV);
      FPComplex#(TAdd#(logn,ri),rf) result = Vector::fold(\+ ,extendedResultV); //build a binary tree structure
      return result;
endfunction // Complex

function Vector#(m,a) insertCP0(Vector#(n,a) inVec)
   provisos (Mul#(4,cpsz,n),Add#(xxA,cpsz,n),Add#(cpsz,n,m));
   Vector#(cpsz,a) cp = takeTail(inVec);
   Vector#(m,a) outVec = append(cp,inVec);
   return outVec;
endfunction

function Vector#(m,a) insertCP1(Vector#(n,a) inVec)
   provisos (Mul#(8,cpsz,n),Add#(xxA,cpsz,n),Add#(cpsz,n,m));
   Vector#(cpsz,a) cp = takeTail(inVec);
   Vector#(m,a) outVec = append(cp,inVec);
   return outVec;
endfunction

function Vector#(m,a) insertCP2(Vector#(n,a) inVec)
   provisos (Mul#(16,cpsz,n),Add#(xxA,cpsz,n),Add#(cpsz,n,m));
   Vector#(cpsz,a) cp = takeTail(inVec);
   Vector#(m,a) outVec = append(cp,inVec);
   return outVec;
endfunction

function Vector#(m,a) insertCP3(Vector#(n,a) inVec)
   provisos (Mul#(32,cpsz,n),Add#(xxA,cpsz,n),Add#(cpsz,n,m));
   Vector#(cpsz,a) cp = takeTail(inVec);
   Vector#(m,a) outVec = append(cp,inVec);
   return outVec;
endfunction

// (* synthesize *)
module mkAutoCorr_DelayIn(ShiftRegs#(SSLen, FPComplex#(SyncIntPrec,SyncFractPrec)));
   ShiftRegs#(SSLen,FPComplex#(SyncIntPrec,SyncFractPrec)) shiftRegs <- mkCirShiftRegsNoGetVec;
   return shiftRegs;
endmodule

// (* synthesize *)
module mkAutoCorr_CorrSub(ShiftRegs#(SSLen, FPComplex#(MulIntPrec,SyncFractPrec)));
   ShiftRegs#(SSLen,FPComplex#(MulIntPrec,SyncFractPrec)) shiftRegs <- mkCirShiftRegsNoGetVec;
   return shiftRegs;
endmodule

// (* synthesize *)
module mkAutoCorr_ExtDelayIn(ShiftRegs#(LSLSSLen, FPComplex#(SyncIntPrec,SyncFractPrec)));
   ShiftRegs#(LSLSSLen,FPComplex#(SyncIntPrec,SyncFractPrec)) shiftRegs <- mkCirShiftRegsNoGetVec;
   return shiftRegs;
endmodule

// (* synthesize *)
module mkAutoCorr_ExtCorrSub(ShiftRegs#(LSLSSLen, FPComplex#(MulIntPrec,SyncFractPrec)));
   ShiftRegs#(LSLSSLen,FPComplex#(MulIntPrec,SyncFractPrec)) shiftRegs <- mkCirShiftRegsNoGetVec;
   return shiftRegs;
endmodule

// (* synthesize *)
module mkTimeEst_CoarPowSub(ShiftRegs#(SSLen, FixedPoint#(MulIntPrec,SyncFractPrec)));
   ShiftRegs#(SSLen,FixedPoint#(MulIntPrec,SyncFractPrec)) shiftRegs <- mkCirShiftRegsNoGetVec;
   return shiftRegs;
endmodule

// (* synthesize *)
module mkTimeEst_CoarTimeSub(ShiftRegs#(CoarTimeAccumDelaySz, Bool));
   ShiftRegs#(CoarTimeAccumDelaySz, Bool) shiftRegs <- mkCirShiftRegsNoGetVec;
   return shiftRegs;
endmodule

// (* synthesize *)
module mkTimeEst_FineDelaySign(ShiftRegs#(FineTimeCorrDelaySz, Complex#(Bit#(1))));
   ShiftRegs#(FineTimeCorrDelaySz, Complex#(Bit#(1))) shiftRegs <- mkShiftRegs;
   return shiftRegs;
endmodule

// (* synthesize *)
module mkFreqEst_FreqOffAccumSub(ShiftRegs#(FreqMeanLen, FixedPoint#(SyncIntPrec,SyncFractPrec)));
   ShiftRegs#(FreqMeanLen, FixedPoint#(SyncIntPrec,SyncFractPrec)) shiftRegs <- mkShiftRegs;
   return shiftRegs;
endmodule
 

/*   
// try to instantiate a crosscorrelation module for 160 elements, otherwise the code is too complicate to compile
(* noinline *)
function Complex#(Bit#(FineTimeCorrResSz)) crossCorrelation160(Vector#(FineTimeCorrSz, Complex#(Bit#(1))) v1, 
							       Vector#(FineTimeCorrSz, Complex#(Bit#(1))) v2); 
      Vector#(FineTimeCorrSz, Complex#(Bit#(1))) v2Conj = Vector::map(singleBitCmplxConj, v2);
      Vector#(FineTimeCorrSz, Complex#(Bit#(3))) multV = Vector::zipWith(singleBitCmplxMult, v1, v2Conj);
      Vector#(FineTimeCorrSz, Complex#(Bit#(FineTimeCorrResSz))) extendedResultV = Vector::map(cmplxSignExtend, multV);
      Complex#(Bit#(FineTimeCorrResSz)) result = Vector::fold(\+ ,extendedResultV); //build a binary tree structure
      return result;
endfunction // Complex

*/








