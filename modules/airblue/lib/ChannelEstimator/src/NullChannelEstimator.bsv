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

// OFDM libraries

// Local Includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

// standard Bluespec libraries
import ClientServer::*;
import Complex::*;
import ConfigReg::*;
import FIFO::*;
import FixedPoint::*;
import GetPut::*;
import Vector::*;


module [Module] mkPiecewiseConstantChannelEstimator#(function Tuple2#(Bool,Bool) 
                                                        resetPilot(ctrl_t ctrl),
                                                     function Tuple2#(Symbol#(CEstPNo,CEstIPrec,CEstFPrec),
                                                                      Symbol#(CEstOutN,CEstIPrec,CEstFPrec)) 
                                                        splitPilot(Symbol#(CEstInN,CEstIPrec,CEstFPrec) in,
                                                                   Bit#(1) p),
                                                     function Vector#(CEstOutN,Tuple2#(Bit#(CEstPBSz),FixedPoint#(CEstIPrec,CEstFPrec)))
                                                        removePilotsAndGuards(Vector#(CEstInN,Tuple2#(Bit#(CEstPBSz),FixedPoint#(CEstIPrec,CEstFPrec))) in),
                                                     function Integer inverseMapping(Integer i),
                                                     Bit#(CEstPSz) prbs_mask,
                                                     Bit#(CEstPSz) init_seq,
                                                     Vector#(CEstPNo,Integer) pilot_locs)
   (ChannelEstimator#(ctrl_t,CEstInN,CEstOutN,CEstIPrec,CEstFPrec))
   provisos (Bits#(ctrl_t, ctrl_sz));
   
   Reg#(Bool)                                               can_read_in_symbol <- mkReg(True);
   Reg#(DemapperMesg#(ctrl_t,CEstOutN,CEstIPrec,CEstFPrec)) out_reg            <- mkRegU;

   interface Put in;
      method Action put(ChannelEstimatorMesg#(ctrl_t,CEstInN,CEstIPrec,CEstFPrec) iMesg)
         if (can_read_in_symbol);
	 let i_ctrl = iMesg.control;
	 let i_data = iMesg.data;
	 let split_data = splitPilot(i_data, ?);
         let o_data = tpl_2(split_data);
	 let o_mesg = Mesg{ control:i_ctrl, data: o_data };

	 out_reg    <= o_mesg;
         can_read_in_symbol <= False;
         if(`DEBUG_CHANNEL_ESTIMATOR == 1)
            begin
               $display("ChannelEst input data:");
               for(Integer i=0; i<valueOf(CEstInN) ; i=i+1)
                  begin
                     $write("ChannelEstIn %d: ",i);
                     fpcmplxWrite(5,i_data[i]);
                     $display("");
                  end         
            end
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(DemapperMesg#(ctrl_t,CEstOutN,CEstIPrec,CEstFPrec)) get()
         if (!can_read_in_symbol);
         can_read_in_symbol <= True;
   
         if(`DEBUG_CHANNEL_ESTIMATOR == 1)
            begin
               for(Integer i=0; i<valueOf(CEstOutN) ; i=i+1)
                  begin
                     $write("ChannelEstOut %d->%d: ",inverseMapping(i),i);
                     fpcmplxWrite(5,out_reg.data[i]);
                     $display("");
                  end 
            end
         
         return out_reg;
      endmethod
   endinterface
endmodule



