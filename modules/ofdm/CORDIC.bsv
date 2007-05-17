///////////////////////////////////////////////////////////////////////////////////////////
//
// File: CORDIC.bsv
// Description: Provides cos, sin and arctan using CORDIC
// Author: Man C Ng, Email: mcn02@mit.edu
// Date: 26, June, 2006
// Last Modified: 10, Oct, 2006
//
//////////////////////////////////////////////////////////////////////////////////////////

import FIFO::*;
import FixedPoint::*;
import Vector::*;

import ofdm_base::*;

// import Pipelines::*;

/////////////////////////////////////////////////////////////////////////////////////////
// Begin of Data Types

// a pair of values representing the result of cos and sin to the same angle
typedef struct
{
  FixedPoint#(ai, af) cos;
  FixedPoint#(ai, af) sin;
 } CosSinPair#(type ai, type af) deriving (Bits, Eq);

// use this type to specify the mode the cordic is operating at
// RotateMode = calculate cos, sin
// VectorMode = calculate arctan
typedef enum {RotateMode, VectorMode} OpMode deriving (Bits, Eq);

// data used at each stage of the CORDIC operations
typedef struct
{
 FixedPoint#(2, vfsz) x;      // coord x
 FixedPoint#(2, vfsz) y;      // coord y
 FixedPoint#(1, afsz) beta;   // angle
 OpMode               mode;   // operation mode
 Bit#(2)              quad;   // this show the quadrant of the input located    
 } CORDICData#(numeric type vfsz, numeric type afsz) deriving (Bits, Eq);  

// End of Data Types
/////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////
// Begin of Interfaces

// visz = no. of bits for the integer part of the output values, 
// vfsz = no. of bits for the fractional part of the output values
// aisz = no. of bits for the integer part of the input angle, 
// afsz = no. of bits for the fractional part of the input angle,
interface CosAndSin#(numeric type visz, numeric type vfsz, numeric type aisz, numeric type afsz);

  method Action putAngle(FixedPoint#(aisz,afsz) x); // input angle

  method ActionValue#(CosSinPair#(visz,vfsz)) getCosSinPair(); // return tuple2 (cos(x),sin(x))

endinterface

// visz = no. of bits for the integer part of the input values, 
// vfsz = no. of bits for the fractional part of the input values
// aisz = no. of bits for the integer part of the output angle, 
// afsz = no. of bits for the fractional part of the output angle,
interface ArcTan#(numeric type visz, numeric type vfsz, numeric type aisz, numeric type afsz);

  method Action putXY(FixedPoint#(visz,vfsz) x, FixedPoint#(visz,vfsz) y); // val of x, y coordinate

  method ActionValue#(FixedPoint#(aisz,afsz)) getArcTan(); // return arcTan(y/x) 

endinterface

// vfsz = no of bits to represent the fractional part of values
// afsz = no of bits to represent the fractional part of angle
interface CORDIC#(numeric type vfsz, numeric type afsz);

  method Action putCORDICData(CORDICData#(vfsz,afsz) x);

  method ActionValue#(CORDICData#(vfsz,afsz)) getCORDICData();

endinterface

// End of Interfaces
/////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////
// Begin of Functions


// begin of auxiliary functions
function CORDICData#(vfsz,afsz) executeStage(Bit#(4) stage, CORDICData#(vfsz, afsz) inData)
  provisos (Arith#(FixedPoint#(2,vfsz)), 
	    Arith#(FixedPoint#(1,afsz)));

      Vector#(16, FixedPoint#(1,afsz)) arcTan_LUT = Vector::toVector(List::cons(
						  fromRational(450000000000,3600000000000), List::cons(  //45.0000000000
                                                  fromRational(265650511771,3600000000000), List::cons(  //26.5650511771
                                                  fromRational(140362434679,3600000000000), List::cons(  //14.0362434679
                                                  fromRational( 71250163489,3600000000000), List::cons(  // 7.1250163489
                                                  fromRational( 35763343749,3600000000000), List::cons(  // 3.5763343749
                                                  fromRational( 17899106082,3600000000000), List::cons(  // 1.7899106082
                                                  fromRational(  8951737102,3600000000000), List::cons(  // 0.8951737102
                                                  fromRational(  4476141709,3600000000000), List::cons(  // 0.4476141709
                                                  fromRational(  2238105004,3600000000000), List::cons(  // 0.2238105004
                                                  fromRational(  1119056771,3600000000000), List::cons(  // 0.1119056771
                                                  fromRational(   559528919,3600000000000), List::cons(  // 0.0559528919
                                                  fromRational(   279764526,3600000000000), List::cons(  // 0.0279764526
                                                  fromRational(   139882271,3600000000000), List::cons(  // 0.0139882271
                                                  fromRational(    69941138,3600000000000), List::cons(  // 0.0069941138
                                                  fromRational(    34970569,3600000000000), List::cons(  // 0.0034970569
                                                  fromRational(    17485284,3600000000000),        // 0.0017485284
                                                  List::nil)))))))))))))))));
      let rotateClockwise = (inData.mode == RotateMode) ? (inData.beta < 0) : (inData.y > 0); // rotation depends on operation
      let gamma = arcTan_LUT[stage];
      let shiftedx = inData.x >> stage; //signed right shift
      let shiftedy = inData.y >> stage; //signed right shift
      let newx = inData.x + (rotateClockwise ? shiftedy : negate(shiftedy));
      let newy = inData.y + (rotateClockwise ? negate(shiftedx) : shiftedx);
      let newBeta = inData.beta + (rotateClockwise ? gamma : negate(gamma));
      return CORDICData{x:newx, y:newy, beta:newBeta, mode:inData.mode, quad:inData.quad};
endfunction

function CORDICData#(vfsz,afsz) execute(CORDICData#(vfsz,afsz) inData, Integer steps)
  provisos (Arith#(FixedPoint#(1,afsz)),
	    Arith#(FixedPoint#(2,vfsz)));

      CORDICData#(vfsz,afsz) v = inData;
      Integer maxN = (steps > 16) ? 15 : steps - 1;
      for(Integer i = 0; i < maxN ; i = i + 1)
	begin
	   Bit#(4) stage = fromInteger(i);
	   v = executeStage(stage, v);
	end
      return v;
endfunction // CORDICData

// right shift
function FixedPoint#(1,rf) convertFP(FixedPoint#(ni,nf) x)
  provisos (Add#(xxA, nf, rf), 
	    Add#(xxA, 1, ni), 
	    Add#(xxA, TAdd#(ni,nf), TAdd#(ni,rf)),
	    Add#(xxB, TAdd#(1,rf), TAdd#(ni,rf)));

      FixedPoint#(ni,rf) inX = fxptSignExtend(x) >> valueOf(xxA);
      FixedPoint#(1,rf) outX =  fxptTruncate(inX); // as if doing right shift by xxA  
      return outX;
endfunction // FixedPoint


// setup the input for cordic data in rotation mode
function CORDICData#(vfsz,afsz) getRotateModeInData(FixedPoint#(aisz,afsz) beta)
  provisos (Add#(xxA,1,aisz),
	    Add#(2,afszl2,afsz),
	    Add#(3,afszl2,TAdd#(1,afsz)),
	    Add#(aisz,afsz,TAdd#(aisz,afsz)),
	    Literal#(FixedPoint#(2,vfsz)));

      Bit#(afsz) tempBeta = pack(fxptGetFrac(beta));
      Tuple2#(Bit#(2), Bit#(afszl2)) {inQuad, betaLSBs} = split(pack(tempBeta));
      FixedPoint#(1,afsz) inBeta = unpack(zeroExtend(betaLSBs));      
      return CORDICData{x:fromRational(607253,1000000),y:0,beta:inBeta,mode:RotateMode, quad:inQuad};
endfunction // CORDICData

// setup the input for cordic data in vector mode
function CORDICData#(rfsz,afsz) getVectorModeInData(FixedPoint#(visz,vfsz) a, FixedPoint#(visz,vfsz) b)
  provisos (Add#(xxA, vfsz, rfsz), 
	    Add#(xxA, 1, visz), 
	    Add#(xxA, TAdd#(visz,vfsz), TAdd#(visz,rfsz)),
	    Add#(xxB, TAdd#(1,rfsz), TAdd#(visz,rfsz)),
	    Add#(1,TAdd#(1,rfsz),TAdd#(2,rfsz)),
	    Arith#(FixedPoint#(1,rfsz)),
	    Literal#(FixedPoint#(1,afsz)));

      
      FixedPoint#(1,rfsz) x = convertFP(a); // right shifD      FixedPoint#(1,rf) inY = convertFP(y);
      FixedPoint#(1,rfsz) y = convertFP(b); // right shifD      FixedPoint#(1,rf) inY = convertFP(y);
      let xIsNeg = x < 0;
      let yIsNeg = y < 0;
      let absX = xIsNeg ? negate(x) : x;
      let absY = yIsNeg ? negate(y) : y;
      let swap = absY > absX;
      let {inX, inY} = swap ? tuple2(absY, x) : tuple2(absX, y);
      Bit#(2) inQuad = {pack(swap), pack(swap ? yIsNeg : xIsNeg)};
      return CORDICData{x:fxptSignExtend(inX),y:fxptSignExtend(inY),beta:0,mode:VectorMode, quad:inQuad};
endfunction // CORDICData

// setup the input for cordic
function CORDICData#(vfsz,afsz) getCORDICInData(CORDICData#(vfsz,afsz) inData)
  provisos (Add#(1, afsz, TAdd#(1, afsz)),
	    Add#(1, TAdd#(1, vfsz), TAdd#(2, vfsz)),
	    Add#(2, afszl2, afsz),
	    Add#(3, afszl2, TAdd#(1, afsz)),
	    Arith#(FixedPoint::FixedPoint#(1, vfsz)),
	    Literal#(FixedPoint::FixedPoint#(2, vfsz)));

      FixedPoint#(1,vfsz) inX = fxptTruncate(inData.x);
      FixedPoint#(1,vfsz) inY = fxptTruncate(inData.y);
      let result = (inData.mode == RotateMode) ? 
		   getRotateModeInData(inData.beta) : 
		   getVectorModeInData(inX,inY);
      return result;
endfunction // CORDICData

// translate the cordic data into result rotation mode
function CosSinPair#(visz,vfsz) getRotateModeOutData(CORDICData#(vfsz,afsz) cData)
  provisos (Add#(1,TAdd#(1,vfsz),TAdd#(2,vfsz)),
	    Add#(xxA,1,visz),
	    Add#(xxA,TAdd#(1,vfsz),TAdd#(visz,vfsz)),
	    Arith#(FixedPoint#(1,vfsz)),
	    Literal#(FixedPoint#(2,vfsz)));
      
      FixedPoint#(1,vfsz) max = maxBound;
      let tempX = (cData.x >= 1) ? max : ((cData.x < 0) ? 0 : fxptTruncate(cData.x)); // overflow detection
      let tempY = (cData.y >= 1) ? max : ((cData.y < 0) ? 0 : fxptTruncate(cData.y)); // overflow detection
      let negateX = negate(tempX);
      let negateY = negate(tempY);
      let {cosV, sinV} = case (cData.quad)
			   2'b00: tuple2(tempX, tempY);
			   2'b01: tuple2(negateY, tempX);
			   2'b10: tuple2(negateX, negateY);
			   2'b11: tuple2(tempY, negateX);
			 endcase; // case(cData.quad)
      return CosSinPair{cos: fxptSignExtend(cosV), sin: fxptSignExtend(sinV)};	   
endfunction // CORDICData



// translate the cordic data into result vector mode
// output range: (-0.5,0.5]
function FixedPoint#(aisz,afsz) getVectorModeOutData(CORDICData#(vfsz,afsz) cData)
  provisos (Add#(xxA,1,aisz),
	    Add#(xxA,TAdd#(1,afsz),TAdd#(aisz,afsz)),
	    Arith#(FixedPoint#(1,afsz)));

      let angle = cData.beta;
      Tuple2#(FixedPoint#(1,afsz),FixedPoint#(1,afsz))
	tempTuple = case (cData.quad)
			2'b00 : tuple2(0, angle);
			2'b01 : tuple2(((angle < 0) ? fromRational(-1,2) : fromRational(1,2)), negate(angle));
			2'b10 : tuple2(fromRational(1,4), negate(angle));
			2'b11 : tuple2(fromRational(-1,4), angle);
		      endcase;
      FixedPoint#(1,afsz) result = tpl_1(tempTuple) + tpl_2(tempTuple);
      return fxptSignExtend(result);
endfunction // CORDICData

// translate the cordic data into result
function CORDICData#(vfsz,afsz) getCORDICOutData(CORDICData#(vfsz,afsz) cData)
  provisos (Add#(1,TAdd#(1,vfsz),TAdd#(2,vfsz)),
	    Arith#(FixedPoint#(1,vfsz)),
	    Arith#(FixedPoint#(1,afsz)),
	    Literal#(FixedPoint#(2,vfsz)));

      CosSinPair#(1,vfsz) cosSinPair = getRotateModeOutData(cData);
      FixedPoint#(2,vfsz) cosV = fxptSignExtend(cosSinPair.cos);
      FixedPoint#(2,vfsz) sinV = fxptSignExtend(cosSinPair.sin);
      let atan = getVectorModeOutData(cData);
      return CORDICData{x:cosV, y:sinV, beta:atan, mode:cData.mode, quad:cData.quad};
endfunction // CORDICData


// end of auxiliary functions

// input: angle (in terms of no of full circle, e.g. pi = 1/2)
//        steps (no of iterations executed, max 16)
// output: tuple2(cos(angle), sin(angle))
function CosSinPair#(ni, nf) getCosSinPair(FixedPoint#(hi, hf) angle, Integer steps)
  provisos (Add#(xxA,1,hi),
	    Add#(2,hfl2,hf),
	    Add#(3,hfl2,TAdd#(1,hf)),
	    Add#(hi,hf,TAdd#(hi,hf)),
	    Literal#(FixedPoint#(2,nf)),
	    Add#(1,TAdd#(1,nf),TAdd#(2,nf)),
	    Add#(xxB,1,ni),
	    Add#(xxB,TAdd#(1,nf),TAdd#(ni,nf)),
	    Arith#(FixedPoint#(1,nf)),
	    Literal#(FixedPoint#(2,nf)),
	    Arith#(FixedPoint#(1,hf)),
	    Arith#(FixedPoint#(2,nf)));
          
      CORDICData#(nf,hf) inData  = getRotateModeInData(angle);
      CORDICData#(nf,hf) outData = execute(inData, steps);
      CosSinPair#(ni,nf)  result  = getRotateModeOutData(outData);
      return CosSinPair{cos: result.cos, sin: result.sin};
endfunction // CosSinPair


// input: angle (in terms of no of full circle, e.g. pi = 1/2)
//        steps (no of iterations executed, max 16)
// output: cos(angle)
function FixedPoint#(ni, nf) cos(FixedPoint#(hi, hf) angle, Integer steps)
  provisos (Add#(xxA,1,hi),
	    Add#(2,hfl2,hf),
	    Add#(3,hfl2,TAdd#(1,hf)),
	    Add#(hi,hf,TAdd#(hi,hf)),
	    Literal#(FixedPoint#(2,nf)),
	    Add#(1,TAdd#(1,nf),TAdd#(2,nf)),
	    Add#(xxB,1,ni),
	    Add#(xxB,TAdd#(1,nf),TAdd#(ni,nf)),
	    Arith#(FixedPoint#(1,nf)),
	    Literal#(FixedPoint#(2,nf)),
	    Arith#(FixedPoint#(1,hf)),
	    Arith#(FixedPoint#(2,nf)));

      let result = getCosSinPair(angle, steps);
      return result.cos;
endfunction // FixedPoint


// input: angle (in terms of no of full circle, e.g. pi = 1/2)
//        steps (no of iterations executed, max 16)
// output: sin(angle)
function FixedPoint#(ni, nf) sin(FixedPoint#(hi, hf) angle, Integer precision)
  provisos (Add#(xxA,1,hi),
	    Add#(2,hfl2,hf),
	    Add#(3,hfl2,TAdd#(1,hf)),
	    Add#(hi,hf,TAdd#(hi,hf)),
	    Literal#(FixedPoint#(2,nf)),
	    Add#(1,TAdd#(1,nf),TAdd#(2,nf)),
	    Add#(xxB,1,ni),
	    Add#(xxB,TAdd#(1,nf),TAdd#(ni,nf)),
	    Arith#(FixedPoint#(1,nf)),
	    Literal#(FixedPoint#(2,nf)),
	    Arith#(FixedPoint#(1,hf)),
	    Arith#(FixedPoint#(2,nf)));

      let result = getCosSinPair(angle, precision);
      return result.sin;
endfunction // FixedPoint

// input: x, y (coord value for x, y axes)
//        precision (no of iterations executed, max 16)
// output: atan(y/x) (in terms of no of full circle, e.g. pi = 1/2) 
function FixedPoint#(hi, hf) atan(FixedPoint#(ni, nf) x, FixedPoint#(ni,nf) y, Integer steps)
  provisos (Add#(xxA, nf, rf), 
	    Add#(xxA, TAdd#(ni,nf), TAdd#(ni,rf)),
	    Add#(xxA, 1, ni),
	    Add#(xxB, TAdd#(1,rf), TAdd#(ni,rf)),
	    Add#(xxC, TAdd#(1,hf), TAdd#(hi,hf)),
	    Add#(xxC, 1, hi),
	    Add#(1,TAdd#(1,rf),TAdd#(2,rf)),
	    Arith#(FixedPoint#(1,rf)),
	    Arith#(FixedPoint#(1,hf)),
	    Arith#(FixedPoint#(2,rf)),
	    Literal#(FixedPoint#(1,hf)));

      CORDICData#(rf,hf) inData  = getVectorModeInData(x,y);
      CORDICData#(rf,hf) outData = execute(inData, steps);
      FixedPoint#(1,hf)  result  = getVectorModeOutData(outData);
      return fxptSignExtend(result);
endfunction // FixedPoint
      
// End of Functions
/////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////
// Begin of Modules

module [Module] mkCORDIC#(Module#(Pipeline#(CORDICData#(vfsz,afsz))) mkP)
              (CORDIC#(vfsz,afsz));

   Pipeline#(CORDICData#(vfsz,afsz)) p <- mkP(); 
  
   method Action putCORDICData(CORDICData#(vfsz,afsz) x);
   begin
      p.put(x);
   end
   endmethod

   // output to cyclic extend queue method

   method ActionValue#(CORDICData#(vfsz,afsz)) getCORDICData();
   begin
      let result <- p.get();
      return result;
   end
   endmethod

endmodule

// for making cordic pipeline
module [Module] mkCORDIC_Pipe#(Integer numStages, Integer step)(CORDIC#(vfsz,afsz))
  provisos (Arith#(FixedPoint#(2, vfsz)),
	    Add#(1, afsz, TAdd#(1, afsz)),
	    Arith#(FixedPoint#(1, vfsz)),
	    Add#(3, afszl2, TAdd#(1, afsz)),
	    Add#(2, afszl2, afsz),
	    Add#(1, TAdd#(1, vfsz), TAdd#(2, vfsz)));
   
   CORDIC#(vfsz,afsz) cordic <- mkCORDIC(mkPipeline_Sync(numStages, step, executeStage));

   method Action putCORDICData(CORDICData#(vfsz,afsz) x);
      cordic.putCORDICData(getCORDICInData(x));
   endmethod
     
   method ActionValue#(CORDICData#(vfsz,afsz)) getCORDICData();
      let outData <- cordic.getCORDICData();
      return getCORDICOutData(outData);
   endmethod

endmodule

// for making CosAndSin pipeline
module [Module] mkCosAndSin_Pipe#(Integer numStages, Integer step)(CosAndSin#(visz, vfsz, aisz, afsz))
  provisos (Arith#(FixedPoint#(2, vfsz)),
	    Arith#(FixedPoint#(1, afsz)),
	    Add#(xxA, 1, aisz),
	    Add#(2, afszl2, afsz),
	    Add#(3, afszl2, TAdd#(1, afsz)),
	    Add#(aisz, afsz, TAdd#(aisz, afsz)),
	    Add#(1, TAdd#(1, vfsz), TAdd#(2, vfsz)),
	    Add#(xxB, 1, visz),
	    Add#(xxB, TAdd#(1, vfsz), TAdd#(visz, vfsz)),
	    Arith#(FixedPoint#(1, vfsz)));
   
   CORDIC#(vfsz,afsz) cordic <- mkCORDIC(mkPipeline_Sync(numStages, step, executeStage));

   method Action putAngle(FixedPoint#(aisz,afsz) beta);
      cordic.putCORDICData(getRotateModeInData(beta));
   endmethod
     
   method ActionValue#(CosSinPair#(visz,vfsz)) getCosSinPair();
      let outData <- cordic.getCORDICData();
      return getRotateModeOutData(outData);
   endmethod

endmodule

// for making ArcTan  pipeline
module [Module] mkArcTan_Pipe#(Integer numStages, Integer step)(ArcTan#(visz,vfsz,aisz,afsz))
  provisos (Add#(xxA, vfsz, rf), 
	    Add#(xxA, TAdd#(visz,vfsz), TAdd#(visz,rf)),
	    Add#(xxA, 1, visz),
	    Add#(xxB, TAdd#(1,rf), TAdd#(visz,rf)),
	    Add#(xxC, TAdd#(1,afsz), TAdd#(aisz,afsz)),
	    Add#(xxC, 1, aisz),
	    Add#(1,TAdd#(1,rf),TAdd#(2,rf)),
	    Arith#(FixedPoint#(1,rf)),
	    Arith#(FixedPoint#(1,afsz)),
	    Arith#(FixedPoint#(2,rf)),
	    Literal#(FixedPoint#(1,afsz)));

   
   CORDIC#(rf,afsz) cordic <- mkCORDIC(mkPipeline_Sync(numStages, step, executeStage));

   method Action putXY(FixedPoint#(visz,vfsz) x, FixedPoint#(visz,vfsz) y);
      CORDICData#(rf,afsz) inData = getVectorModeInData(x,y);
      cordic.putCORDICData(inData);
   endmethod
     
   method ActionValue#(FixedPoint#(aisz,afsz)) getArcTan();
      let outData <- cordic.getCORDICData();
      return getVectorModeOutData(outData);
   endmethod

endmodule // mkArcTan_Pipe

// End of Modules
/////////////////////////////////////////////////////////////////////////////////////////








