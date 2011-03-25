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
import Vector::*;

// import Controls::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
// import StreamFIFO::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/provides/librl_bsv_storage.bsh"

//`define debug_mode True // uncomment this line for displaying text

// internal state
typedef enum{ UN_Bypass, UN_Skip } UnserialState deriving (Bits,Eq);
	     
module mkUnserializer(Unserializer#(n,i_prec,f_prec))
   provisos (Log#(n,n_idx),
             Add#(n,1,n_p_1),
             Log#(n_p_1,n_s_sz),
             Bits#(FPComplex#(i_prec,f_prec),data_sz),
             Mul#(n,data_sz,t_sz),
             Add#(t_sz,1,t_sz_p_1),
             Log#(t_sz_p_1,t_s_sz),
             Add#(xxA,n_s_sz,t_s_sz));
//    provisos (Log#(n,n_idx),   
//              Add#(n,1,n_p_1),
//              Log#(n_p_1,n_s_sz));
   
   // constants/ wires
   Integer nInt = valueOf(n);
   Bit#(n_s_sz) nSz = fromInteger(nInt);
   Bit#(n_idx) bypassCheckSz = fromInteger(nInt - 1);

   // state elements
   FIFOF#(UnserializerMesg#(i_prec,f_prec))  inQ <- mkLFIFOF;          // store incoming stream
   NumTypeParam#(2048) p = ?;
   FIFOF#(UnserializerMesg#(i_prec,f_prec))  inQ2 <- mkSizedBRAMFIFOF(p); //store data with CP removed
   StreamFIFO#(n,n_s_sz,FPComplex#(i_prec,f_prec)) outQ;
   outQ <- mkStreamFIFO();
   Reg#(SyncCtrl) ctrl <- mkReg(SyncCtrl{isNewPacket: False, cpSize: CP0}) ;
   Reg#(Bit#(n_idx)) index <- mkReg(bypassCheckSz);
   Reg#(UnserialState) state <- mkReg(UN_Bypass);
   Reg#(Bit#(n_idx)) skipCheckSz <- mkReg(fromInteger(nInt/4 - 1));
   
   // constants/ wires   
   let inMsg = inQ.first();
   let isNewMsg = inMsg.control.isNewPacket;
   let inData = inMsg.data;
   let isSkip = state == UN_Skip;
   let isBypass = state == UN_Bypass;
   let inMsg2 = inQ2.first();
   let isNewMsg2 = inMsg2.control.isNewPacket;
   let inData2 = inMsg2.data;

   if(`DEBUG_UNSERIALIZER == 1)
      begin
   
         rule inQFull (!inQ.notFull);
            $display("Unserializer inQ full");
         endrule
         
         rule inQEmpty (!inQ.notEmpty);
            $display("Unserializer inQ empty");
         endrule
 
         rule inQ2Full (!inQ2.notFull);
            $display("Unserializer inQ2 full");
         endrule

         rule inQ2Empty (!inQ2.notEmpty);
            $display("Unserializer inQ2 empty");
         endrule
 
         rule outQEmpty (!outQ.notEmpty(1));
            $display("Unserializer outQ empty");
         endrule
         
         rule outQFull (!outQ.notFull(1));
            $display("Unserializer outQ full");
         endrule
         
      end

   rule getNewCtrl(isNewMsg);
      let newSkipCheckSz = case (inMsg.control.cpSize) 
			      CP0: fromInteger(nInt/4 - 1);
			      CP1: fromInteger(nInt/8 - 1);
			      CP2: fromInteger(nInt/16 - 1);
			      CP3: fromInteger(nInt/32 - 1);
		           endcase;
      inQ.deq();
      index <= newSkipCheckSz-1;
      skipCheckSz <= newSkipCheckSz;
      state <= UN_Skip;
      inQ2.enq(inMsg);
      if(`DEBUG_UNSERIALIZER == 1)
         $display("Unserializer Rule getNewCtrl fired: %d data %x", inMsg.control.isNewPacket, inMsg.data);
      
   endrule

   rule skipMsg(!isNewMsg && isSkip);
      inQ.deq();
      if (index == 0)
	 begin
	    index <= bypassCheckSz;
	    state <= UN_Bypass;
	 end
      else
	 index <= index - 1;
      if(`DEBUG_UNSERIALIZER == 1)
         $display("Unserializer Rule skipMsg fired %d times remained data %x", index, inMsg.data);
      
   endrule

   rule bypassMsg(!isNewMsg && isBypass);
      inQ.deq();
      inQ2.enq(inMsg);
      if (index == 0)
	 begin
	    index <= skipCheckSz;
	    state <= UN_Skip;
	 end
      else
	 begin
	    index <= index - 1;
	 end
      if(`DEBUG_UNSERIALIZER == 1)
	 $display("Unserializer Rule bypassMsg fired %d times remained data %x",index, inMsg.data);
      
   endrule
   
   rule getNewCtrl2(isNewMsg2 && !outQ.notEmpty(nSz));
   begin
      inQ2.deq();
      ctrl <= inMsg2.control;
      outQ.clear();
      if(`DEBUG_UNSERIALIZER == 1)
         $display("Unserializer Rule getNewCtrl2 fired: %d data %x", inMsg2.control.isNewPacket,inMsg2.data);
      
   end
   endrule

   rule bypassMsg2(!isNewMsg2 && outQ.notFull(1));
   begin
      inQ2.deq();
      outQ.enq(1,replicate(inData2));
      if(`DEBUG_UNSERIALIZER == 1)
	 $display("Unserializer Rule bypassMsg2 fired data %x", inMsg2.data);
      
   end
   endrule
   
   // interfaces
   interface Put in;
     method Action put(UnserializerMesg#(i_prec,f_prec) msg);
        inQ.enq(msg);
        if(`DEBUG_UNSERIALIZER == 1)
           $display("Unserializer input isNewPacket %d data %x",msg.control.isNewPacket,msg.data);
        
     endmethod
   endinterface 

   interface Get out;
      method ActionValue#(SPMesgFromSync#(n,i_prec,f_prec)) 
         get() if (outQ.notEmpty(nSz)); 
         outQ.deq(nSz);
         ctrl <= SyncCtrl{isNewPacket: False,
                          cpSize:  ctrl.cpSize};
         if(`DEBUG_UNSERIALIZER == 1)
            $display("Unserializer output isNewPacket %d data %x",ctrl.isNewPacket,outQ.first());
         
         return SPMesgFromSync{control: ctrl.isNewPacket, 
                               data:    outQ.first()};
      endmethod
   endinterface
endmodule




