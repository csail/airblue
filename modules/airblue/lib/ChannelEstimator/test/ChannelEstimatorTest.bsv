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
import GetPut::*;
import Vector::*;

// import Interfaces::*;
// import LibraryFunctions::*;
// import ChannelEstimator::*;
// import ProtocolParameters::*;
// import PilotInsert::*;
// import FPComplex::*;
// import DataTypes::*;
// import Controls::*;

`include "asim/provides/airblue_types.bsh"
`include "asim/provides/arblue_common.bsh"
`include "asim/provides/airblue_pilot_insert.bsh"
`include "asim/provides/airblue_channel_estimator.bsh"
`include "asim/provides/airblue_parameters.bsh"

import "BDPI" simChannelResponse = 
       function FPComplex#(2,14) simChannelResponse(FPComplex#(2,14) in, Bit#(6) idx);

function t idFunc (t in);
   return in;
endfunction

function Symbol#(64,2,14) pilotAdder(Symbol#(48,2,14) x, 
				     Bit#(1) ppv);
   
   Integer i =0, j = 0;
   // assume all guards initially
   Symbol#(64,2,14) syms = replicate(cmplx(0,0));
   
   // data subcarriers
   for(i = 6; i < 11; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 12; i < 25; i = i + 1, j = j + 1)
      syms[i] = x[j]; 
   for(i = 26; i < 32 ; i = i + 1, j = j + 1)
      syms[i] = x[j];  
   for(i = 33; i < 39 ; i = i + 1, j = j + 1)
      syms[i] = x[j];   
   for(i = 40; i < 53 ; i = i + 1, j = j + 1)
      syms[i] = x[j];
   for(i = 54; i < 59 ; i = i + 1, j = j + 1)
      syms[i] = x[j];

   //pilot subcarriers
   syms[11] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[25] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[39] = mapBPSK(False, ppv); // map 1 to -1, 0 to 1
   syms[53] = mapBPSK(True,  ppv); // map 0 to -1, 1 to 1
   
   return syms;
endfunction

function Tuple2#(Bool,Bool) resetPilot (PilotInsertCtrl ctrl);
   return tuple2(ctrl == PilotRst, True);
endfunction

function Tuple2#(Symbol#(4,2,14),
                 Symbol#(48,2,14)) 
   pilotRemover (Symbol#(64,2,14) x,
                 Bit#(1) ppv);   
   Integer i =0, j = 0;
   // assume all guards initially
   Symbol#(4,2,14)  pilots = newVector();
   Symbol#(48,2,14) syms   = newVector();
  
   // data subcarriers
   for(i = 6; i < 11; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 12; i < 25; i = i + 1, j = j + 1)
      syms[j] = x[i]; 
   for(i = 26; i < 32 ; i = i + 1, j = j + 1)
      syms[j] = x[i];  
   for(i = 33; i < 39 ; i = i + 1, j = j + 1)
      syms[j] = x[i];   
   for(i = 40; i < 53 ; i = i + 1, j = j + 1)
      syms[j] = x[i];
   for(i = 54; i < 59 ; i = i + 1, j = j + 1)
      syms[j] = x[i];  
   
   //pilot subcarriers
   pilots[0] = (ppv != 0) ? x[11] : negate(x[11]); // map 1 to -1, 0 to 1
   pilots[1] = (ppv != 0) ? x[25] : negate(x[25]); // map 1 to -1, 0 to1 
   pilots[2] = (ppv != 0) ? x[39] : negate(x[39]); // map 1 to -1, 0 to 1
   pilots[3] = (ppv != 0) ? negate(x[53]) : x[53]; // map 0 to -1, 1 to 1
   
   return tuple2(pilots,syms);
endfunction

(* synthesize *)
module mkChannelEstimatorInstance( ChannelEstimator#(PilotInsertCtrl,64,48,2,14));
   Vector#(4,Integer) pilotLocs = newVector();
   pilotLocs[0] = 11;
   pilotLocs[1] = 25;
   pilotLocs[2] = 39;
   pilotLocs[3] = 53;
   let m <- mkPiecewiseConstantChannelEstimator(resetPilot,
                                                pilotRemover,
                                                removePilotsAndGuards,
                                                inversePilotMapping,
                                                7'b1001000,
                                                7'b1111111,
                                                pilotLocs);
   return m;
endmodule                       

// (* synthesize *)
// module mkChannelEstimatorTest(Empty);

module mkHWOnlyApplication (Empty);   
   PilotInsert#(PilotInsertCtrl,48,64,2,14) pilotInsert;
   pilotInsert <- mkPilotInsert(idFunc,
				pilotAdder,
				7'b1001000,
                                7'b1111111);
   ChannelEstimator#(PilotInsertCtrl,64,48,2,14) channelEstimator;
   channelEstimator <- mkChannelEstimatorInstance;
   Reg#(Bit#(32)) cycle <- mkReg(0);
   
   rule putIntput(True);
      PilotInsertMesg#(PilotInsertCtrl,48,2,14) iMesg;
      iMesg = Mesg{ control: (cycle[2:0] == 0) ? 
		              PilotRst : 
		              PilotNorm,
		   data: replicate(cmplx(1,0))};
      pilotInsert.in.put(iMesg);
      for (Integer i = 0; i < 48; i = i + 1)
         begin
            $write("Pilot Insert Input idx %d: ",i);
            fpcmplxWrite(5,iMesg.data[i]);
            $display(" at cycle %d",cycle);
         end
   endrule
  
   rule putChannel(True);
      let oMesg <- pilotInsert.out.get;
      let oData = oMesg.data;
      Symbol#(64,2,14) newData = newVector;
      for (Integer i = 0; i < 64; i = i + 1)
         begin
            newData[i] = simChannelResponse(oData[i],fromInteger(i));
            $write("Pilot Insert Output + Channel Response idx %d: ",i);
            fpcmplxWrite(5,oData[i]);
            $write ("-> ");
            fpcmplxWrite(5,newData[i]);
            $display(" at cycle %d",cycle);
         end
      let newMesg = Mesg{ control: oMesg.control, data: newData };
      channelEstimator.in.put(newMesg);
   endrule
   
   rule getOutput(True);
      let oMesg <- channelEstimator.out.get;
      for (Integer i = 0; i < 48; i = i + 1)
         begin
            $write("Channel Estimator Ouput idx %d: ",i);
            fpcmplxWrite(5,oMesg.data[i]);
            $display(" at cycle %d",cycle);
         end
   endrule
   
   rule tick(True);
      cycle <= cycle + 1;
      if (cycle == 100000)
	 $finish;
   endrule
   
endmodule



