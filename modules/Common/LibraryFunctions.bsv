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

import Vector::*;
import FPComplex::*;
import Complex::*;
import FixedPoint::*;
import GetPut::*;
import Connectable::*;
import FIFO::*;
import FIFOLevel::*;
import ShiftRegs::*;


//Given a Bit#(n) returns it's parity
function Bit#(1) getParity(Bit#(n) v) provisos(Add#(1, k, n));
  function Bit#(1) _xor(Bit#(1) x, Bit#(1) y);
    return (x ^ y);
  endfunction

  Vector#(n,Bit#(1)) vv = unpack(v);
  Bit#(1) parity = Vector::fold(_xor, vv);
  return(parity);
endfunction

// reverse the bits
function Bit#(n) reverseBits(Bit#(n) x);
  Vector#(n, Bit#(1)) vx  = unpack(x);
  Vector#(n, Bit#(1)) rvx = Vector::reverse(vx);
  Bit#(n)            prvx = pack(rvx);
  return(prvx);
endfunction


// right shift no of bits (the amount of shifting is the first arg
function Bit#(n) rightShiftBy(Nat shiftSz, Bit#(n) x);
  return x >> shiftSz;
endfunction // Bits

// left shift no of bits (the amount of shifting is the first arg
function Bit#(n) leftShiftBy(Nat shiftSz, Bit#(n) x);
  return x << shiftSz;
endfunction // Bits

// return the top (i.e. sign) bit
function Bit#(1) signBit(Bit#(n) x) provisos(Add#(1,k,n));
  match {.signbit,.rest} = split(x);
  return(signbit); 
endfunction


// performs zipwith with 4 vectors
function Vector#(sz, any_e) zipWith4(function any_e f(any_a a, any_b b, any_c c, any_d d),
	                    Vector#(sz, any_a) va, Vector#(sz, any_b) vb,
						Vector#(sz, any_c) vc, Vector#(sz, any_d) vd);

  Vector#(sz, any_e) ve = replicate(?);

  for(Integer i = 0; i < valueOf(sz); i = i + 1)
	  ve[i] = f(va[i],vb[i],vc[i],vd[i]);

  return(ve);

endfunction
  
  
//break up a value
function Vector#(n, Bit#(m)) bitBreak(Bit#(nm) x) provisos(Mul#(n,m,nm));
  return unpack(x);
endfunction
  
//merge a value back together
function Bit#(nm) bitMerge(Vector#(n, Bit#(m)) x) provisos(Mul#(n,m,nm));
  return pack(x);
endfunction
  
//drop values from the left  
function Vector#(n, alpha) sv_truncate(Vector#(m, alpha) in) provisos(Add#(n,k,m));
   Vector#(n, alpha) retval = newVector();
   for(Integer i = valueOf(n) - 1, Integer j = valueOf(m) - 1;  i >= 0; i = i - 1, j = j - 1)
      begin
	 retval[i] = in[j];
      end
       
   return (retval);
endfunction
  
  //drop values from the right
function Vector#(n, alpha) sv_rtruncate(Vector#(m, alpha) in) provisos(Add#(k,n,m));
   Vector#(n, alpha) retval = newVector();
   for(Integer i = 0; i < valueOf(n); i = i + 1)
      begin
	 retval[i] = in[i];
      end
   return (retval);
endfunction

function FPComplex#(b,sz) mapBPSK(Bool negateInput, Bit#(1) data) provisos(Literal#(FixedPoint#(b,sz)), Add#(1,x,b));
   data = negateInput ? ~data : data;
   return Complex{rel: (data[0] == 1)? 1 : -1,
		  img: 0};
endfunction

function FPComplex#(b,sz) mapQPSK(Bool negateInput, Bit#(2) data) provisos(Literal#(FixedPoint#(b,sz)), Add#(1,x,b));
   data = negateInput ? ~data : data;
   return Complex{
           rel: (data[0] == 1)? fromRational(100000000000,141421356237) : fromRational(-100000000000,141421356237),
           img: (data[1] == 1)? fromRational(100000000000,141421356237) : fromRational(-100000000000,141421356237)
      };
endfunction

function FPComplex#(b,sz) mapQAM_16(Bool negateInput, Bit#(4) data) provisos(Literal#(FixedPoint#(b,sz)), Add#(1,x,b));
    function f(x);
        case (x) matches
            2'b01: return fromRational(-300000000000,316227766017);
            2'b00: return fromRational(-100000000000,316227766017);
            2'b11: return fromRational(300000000000,316227766017);
            2'b10: return fromRational(100000000000,316227766017);
        endcase
    endfunction
    data = negateInput ? ~data : data;
    return Complex{
        rel: f({data[0],data[1]}),
        img: f({data[2],data[3]})
    };
endfunction
   
function FPComplex#(b,sz) mapQAM_64(Bool negateInput, Bit#(6) data) provisos(Literal#(FixedPoint#(b,sz)), Add#(1,x,b));
    function f(x);
        case (x) matches
            3'b000: return fromRational(-700000000000,648074069841);
            3'b001: return fromRational(-500000000000,648074069841);
            3'b011: return fromRational(-300000000000,648074069841);
            3'b010: return fromRational(-100000000000,648074069841);
            3'b110: return fromRational(100000000000,648074069841);
            3'b111: return fromRational(300000000000,648074069841);
            3'b101: return fromRational(500000000000,648074069841);
            3'b100: return fromRational(700000000000,648074069841);
        endcase
    endfunction
    data = negateInput ? ~data : data;
    return Complex{
        rel: f({data[0],data[1],data[2]}),
        img: f({data[3],data[4],data[5]})
    };
endfunction
   
   
// a function to add CP
function Vector#(o_sz, t) addCP(Vector#(i_sz, t) inVec)
   provisos (Add#(diff_sz,i_sz,o_sz),
	     Add#(xxA,diff_sz,i_sz));
   Vector#(diff_sz,t) cp = takeTail(inVec);
   return append(cp,inVec);
endfunction
   
// a function that generates xors feedback according to mask
function Bit#(1) genXORFeedback(Bit#(n) mask, Bit#(n) inData)
   provisos (Add#(1,xxA,n));   
   Bit#(1) res = 0;
   for (Integer i = 0; i < valueOf(n); i = i + 1)
      if (mask[i] == 1)
	 res = res ^ inData[i];
   return res;
endfunction   
			   
// similar to map, but the function take 2 vec arguements
function Vector#(sz,c) map2(function c f(a x, b y),
			    Vector#(sz,a) xs,
			    Vector#(sz,b) ys);
   
   function c fTup(Tuple2#(a,b) tup);
      return f(tpl_1(tup),tpl_2(tup));
   endfunction
			       
   let tupVec = zip(xs,ys);
   return map(fTup,tupVec);
endfunction
   
// similar to map, but the function take 3 vec arguements
function Vector#(sz,d) map3(function d f(a x, b y, c z),
			    Vector#(sz,a) xs,
			    Vector#(sz,b) ys,
			    Vector#(sz,c) zs);
   
   function d fTup(Tuple3#(a,b,c) tup);
      return f(tpl_1(tup),tpl_2(tup),tpl_3(tup));
   endfunction
			       
   let tupVec = zip3(xs,ys,zs);
   return map(fTup,tupVec);
endfunction

// similar to foldl, but the function take 2 vec arguements
   function a foldl2(function a f(a x, b y, c z),
		     a x_fst,
		     Vector#(sz,b) ys,
		     Vector#(sz,c) zs);
   
   function a fTup(a x, Tuple2#(b,c) tup);
      return f(x,tpl_1(tup),tpl_2(tup));
   endfunction
			       
   let tupVec = zip(ys,zs);
   return foldl(fTup,x_fst,tupVec);
endfunction
   
// print data of connection   
module mkConnectionPrint#(String str, Get#(t) g, Put#(t) p) (Empty)
   provisos (Bits#(t,t_sz));
   rule connect(True);
      let mesg <- g.get;
      p.put(mesg);
      $display("%s: %h",str,mesg);
   endrule
endmodule

module mkConnectionThroughput#(String str, Get#(t) g, Put#(t) p) (Empty)
   provisos (Bits#(t,t_sz));
 
   FIFOCountIfc#(t,1024) buffer <- mkFIFOCount();

   Reg#(Bit#(64)) trueCount <- mkReg(0);
   Reg#(Bit#(64)) actualCountIn <- mkReg(0);
   Reg#(Bit#(64)) burstCountIn <- mkReg(0);   
   Reg#(Bit#(64)) actualCountOut <- mkReg(0);
   Reg#(Bit#(64)) burstCountOut <- mkReg(0);   
   PulseWire tickBurstIn <- mkPulseWire;
   PulseWire tickBurstOut <- mkPulseWire;
   ShiftRegs#(200,Bit#(1))  historyIn <- mkShiftRegs(); 
   ShiftRegs#(200,Bit#(1))  historyOut <- mkShiftRegs(); 

   let fifoCount <- mkDWire(0);

  (* fire_when_enabled *)
   rule setFifoCount;
     fifoCount <= buffer.count;
   endrule 


   (* fire_when_enabled *)
   rule tickTrue;
     trueCount <= trueCount + 1;
   endrule 


   (* fire_when_enabled *)
   rule connectIn;
      tickBurstIn.send;
      actualCountIn<= actualCountIn + 1;
      let mesg <- g.get;
      buffer.enq(mesg);
      Bit#(32) count = fold( \+ ,map(zeroExtend,historyIn.getVector()));
      $display("ThroughputIn:%s:Count:%d:Time:%d:Histroy:%d:currentBurst:%d:Count:%d",str,actualCountIn,trueCount,count,burstCountIn,fifoCount);
   endrule   

   (* fire_when_enabled *)
   rule connectOut;
      tickBurstOut.send;
      actualCountOut <= actualCountOut + 1;
      buffer.deq;
      p.put(buffer.first);
      Bit#(32) count = fold( \+ ,map(zeroExtend,historyOut.getVector()));
      $display("ThroughputOut:%s:Count:%d:Time:%d:Histroy:%d:currentBurst:%d:Count:%d",str,actualCountOut,trueCount,count,burstCountOut,fifoCount);
   endrule

   (* fire_when_enabled *)
   rule updateHistoryIn;
     if(tickBurstIn)
       begin
         historyIn.enq(1);
       end
     else
       begin
         historyIn.enq(0);
       end
   endrule

   (* fire_when_enabled *)
   rule updateHistoryOut;
     if(tickBurstOut)
       begin
         historyOut.enq(1);
       end
     else
       begin
         historyOut.enq(0);
       end
   endrule

   (* fire_when_enabled *)
   rule tickBurstCountIn(tickBurstIn);
     burstCountIn <= burstCountIn + 1;
   endrule

   (* fire_when_enabled *)
   rule resetBurstCountIn(!tickBurstIn);
     burstCountIn <= 0;
   endrule

   (* fire_when_enabled *)
   rule tickBurstCountOut(tickBurstOut);
     burstCountOut <= burstCountOut + 1;
   endrule

   (* fire_when_enabled *)
   rule resetBurstCountOut(!tickBurstOut);
     burstCountOut <= 0;
   endrule
endmodule

function Tuple2#(Bit#(1),Bit#(shifter_sz)) 
   scramble(Bit#(shifter_sz) genPoly,
	    Tuple2#(Bit#(1),Bit#(shifter_sz)) tup,
	    Bit#(1) inBit)
   provisos (Add#(1,xxA,shifter_sz));
   let curSeq = tpl_2(tup);
   let fback = genXORFeedback(genPoly,curSeq);
   Vector#(shifter_sz,Bit#(1)) oVec = shiftInAt0(unpack(curSeq),fback);
   let oSeq = pack(oVec);
   let oBit = fback ^ inBit;
   return tuple2(oBit,oSeq);
endfunction
