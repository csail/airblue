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
//import ChannelEstimatorTypes::*;
// import ComplexLibrary::*;
// import Controls::*;
// import CORDIC::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
// import LibraryFunctions::*;
// import InverseSqRootParams::*;
// import InverseSqRoot::*;

// Local Includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_inverse_sq_root.bsh"

// standard Bluespec libraries
import ClientServer::*;
import Complex::*;
import ConfigReg::*;
import FIFO::*;
import FixedPoint::*;
import GetPut::*;
import Vector::*;

//`define isDebug True  // uncomment this line to display error
`define cordicIters 16 // no. iterations cordic performs before giving result
`define cordicItersPerStage 8 // no. pipeline iters per stages

/////////////////////////////////////////////////////////////////////////
// Definitions of Auxiliary Functions

// this function determines the affine coeffcients for a two point linear interpolation
// The affine function takes the form a + C(b-a), where a and b are two scaling coefficients.
// This function will determine the C coeffcient, which is a scalar  
function Vector#(out_n,Tuple2#(Bit#(p_sz),FixedPoint#(i_prec,f_prec))) determineAffineCoefficients(Vector#(p_no,Integer) pilotLocs)
   provisos(RealLiteral#(FixedPoint#(i_prec,f_prec)),
            Literal#(FixedPoint::FixedPoint#(i_prec, f_prec)),
            Log#(p_no,p_sz));
   Vector#(out_n,Tuple2#(Bit#(p_sz),FixedPoint#(i_prec,f_prec))) coefs = replicate(tuple2(0,-1));
   //Handle pilot 0 special		
   Integer index = 0;
   
   // this affine stuff is not properly scaled.
   for(Integer i = 0; i <= pilotLocs[0]; i=i+1, index=index+1)
      begin
         Real slopeDenominator = fromInteger(pilotLocs[1]-pilotLocs[0]);
         Real slopeNumerator = fromInteger(i - pilotLocs[0]);
         // need magnitude here 
         coefs[index] = tuple2(0,fromReal(slopeNumerator/slopeDenominator));
      end 
   
   for(Integer pilotNo = 0; pilotNo<valueof(p_no)-1; pilotNo = pilotNo + 1)
      begin
         for(Integer i = 0; i < pilotLocs[pilotNo+1] - pilotLocs[pilotNo]; i=i+1, index=index+1)
            begin          
               Real slopeDenominator = fromInteger(pilotLocs[pilotNo+1]-pilotLocs[pilotNo]);
               Real slopeNumerator = fromInteger(i+1);
               // need magnitude here 
               coefs[index] = tuple2(fromInteger(pilotNo),fromReal(slopeNumerator/slopeDenominator));   
            end       
      end  
   
   //Handle pilot p_no-1 special
   for(Integer i = 1; index < valueof(out_n); i=i+1, index=index+1)
      begin          
         Real slopeDenominator = fromInteger(pilotLocs[valueof(p_no)-1]-pilotLocs[valueof(p_no)-2]);
         Real slopeNumerator = fromInteger(i+pilotLocs[valueof(p_no)-1]-pilotLocs[valueof(p_no)-2]);
         // need magnitude here 
         coefs[index] =  tuple2(fromInteger(valueOf(p_no)-2),fromReal(slopeNumerator/slopeDenominator)); 
         
      end       
   return coefs; 
endfunction

// this function get angle_0 - angle_1 represented in fixedpoint, it is assume the difference is always less than 0.5, i.e half a circle 
function FixedPoint#(i_prec,f_prec) getAngleDiff(FixedPoint#(i_prec,f_prec) angle_0, FixedPoint#(i_prec,f_prec) angle_1)
   provisos (Arith#(FixedPoint#(i_prec,f_prec)),
             Ord#(FixedPoint#(i_prec,f_prec)),
             RealLiteral#(FixedPoint#(i_prec,f_prec)));
   FixedPoint#(i_prec,f_prec)          diff_0 = angle_0 - angle_1;
   Tuple2#(FixedPoint#(i_prec,f_prec),
           FixedPoint#(i_prec,f_prec)) check = (diff_0 > 0) ? tuple2(diff_0, (diff_0 - 1)) : tuple2((diff_0 + 1), diff_0); // positive one always come first
   return (tpl_1(check) < 0.5) ? tpl_1(check) : tpl_2(check); // choose the one with absolute value smaller than 0.5
endfunction

/////////////////////////////////////////////////////////////////////////
// Implementation of PathMetricUnit

module  mkPiecewiseConstantChannelEstimator#(function Tuple2#(Bool,Bool) 
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

//    provisos (Bits#(ctrl_t, ctrl_sz),
//              Add#(1,xxA,CEstPSz),
//              Add#(xxA,1,CEstPSz),
//              Log#(CEstOutN,CEstOutSz),
//              Log#(CEstPNo,CEstPBSz),
//              Arith#(FixedPoint#(CEstIPrec,CEstFPrec)),
//              Add#(1,xxB,CEstIPrec),
//              Add#(4,xxC,TAdd#(32,CEstFPrec)),
//              Add#(CEstIPrec,CEstFPrec,TAdd#(CEstIPrec,CEstFPrec)));
                                               
   // constants
   Integer pilot_no = valueOf(CEstPNo);  // no. pilot
   Integer out_no   = valueOf(CEstOutN); // no. output values
   Bit#(CEstOutSz) max_idx = fromInteger(out_no-1);
   Bit#(CEstOutSz) next_p  = fromInteger(out_no/4);
                           
   // state elements
   Reg#(Bool)                                                                   can_interpolate <- mkReg(False);
   Reg#(Bool)                                                                     can_est_pilot <- mkReg(False);
   Reg#(Bool)                                                                can_read_in_symbol <- mkReg(True);
   Reg#(Bool)                                                              can_write_out_symbol <- mkReg(False);
   Reg#(Bit#(CEstOutSz))                                                        interpolate_idx <- mkReg(?);
   Reg#(Bit#(CEstOutSz))                                                           out_read_idx <- mkReg(?);
   Reg#(Bit#(CEstOutSz))                                                          out_write_idx <- mkReg(?);
   Reg#(Bit#(CEstPBSz))                                                           pilot_put_idx <- mkReg(?);
   Reg#(Bit#(CEstPBSz))                                                           pilot_get_idx <- mkReg(?);
   Reg#(Bit#(CEstPSz))                                                               pilot_lfsr <- mkReg(?);
   Reg#(Symbol#(CEstPNo,CEstIPrec,CEstFPrec))                                        pilot_eval <- mkReg(?);
   Reg#(Vector#(CEstPNo,Maybe#(FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec))))   pilot_mag <- mkReg(?);
   Reg#(Vector#(CEstPNo,Maybe#(FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec))))    mag_diff <- mkReg(?);
   Reg#(Vector#(CEstPNo,Maybe#(FixedPoint#(CEstIPrec,CEstFPrec))))                  pilot_angle <- mkReg(?);
   Reg#(Vector#(CEstPNo,Maybe#(FixedPoint#(CEstIPrec,CEstFPrec))))                   angle_diff <- mkReg(?);
   Reg#(DemapperMesg#(ctrl_t,CEstOutN,CEstIPrec,CEstFPrec))                             out_reg <- mkConfigRegU;
                                               
   FIFO#(FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec))                               mag_q <- mkSizedFIFO(2+`cordicIters/`cordicItersPerStage); // 2 to resemble angle_q LFIFO's latency  and extra cordicStages for cos_and_sin latency
   FIFO#(FixedPoint#(CEstIPrec,CEstFPrec))                                              angle_q <- mkSizedFIFO(2);
   FIFO#(FPComplex#(CEstIPrec,CEstFPrec))                                        angle_adjust_q <- mkLFIFO;
   FIFO#(FPComplex#(CEstIPrec,CEstFPrec))                                        mag_adjusted_q <- mkLFIFO;
   
   CosAndSin#(CEstIPrec,CEstFPrec,CEstIPrec,CEstFPrec)                              cos_and_sin <- mkCosAndSin_Pipe(`cordicIters,`cordicItersPerStage);
   ArcTan#(CEstIPrec,CEstFPrec,CEstIPrec,CEstFPrec)                                      arctan <- mkArcTan_Pipe(`cordicIters,`cordicItersPerStage);
   InverseSqRoot#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec)                             inv_sq_root <- mkSimpleInverseSqRoot;  
                                               
   // signals names
   Vector#(CEstInN,Tuple2#(Bit#(CEstPBSz),FixedPoint#(CEstIPrec,CEstFPrec)))  affine_coef_full_vec = determineAffineCoefficients(pilot_locs);
   Vector#(CEstOutN,Tuple2#(Bit#(CEstPBSz),FixedPoint#(CEstIPrec,CEstFPrec))) affine_coef_vec      = removePilotsAndGuards(affine_coef_full_vec);
   Bit#(CEstPBSz)                                                             affine_idx           = tpl_1(affine_coef_vec[interpolate_idx]);
   FixedPoint#(CEstIPrec,CEstFPrec)                                           affine_coef          = tpl_2(affine_coef_vec[interpolate_idx]);
                                               
   // get the inverse of the channel at pilot subcarriers
   rule estimatePilot_put(can_est_pilot);
      // for angle
      arctan.putXY(pilot_eval[pilot_put_idx].rel,pilot_eval[pilot_put_idx].img);
      
      // for magnitude
      FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),TAdd#(CEstFPrec,CEstFPrec)) mag = fxptZeroExtend(fpcmplxModSq(pilot_eval[pilot_put_idx]));
      FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec) short_mag = fxptTruncate(mag);
      inv_sq_root.request.put(short_mag);
      
      // common state update
      pilot_put_idx <= pilot_put_idx - 1;
      if (pilot_put_idx == 0)
         can_est_pilot <= False;
   endrule

   rule estimatePilot_get(True);
      // for angle
      FixedPoint#(CEstIPrec,CEstFPrec) angle <- arctan.getArcTan;
      Vector#(CEstPNo,Maybe#(FixedPoint#(CEstIPrec,CEstFPrec))) new_pilot_angle = pilot_angle;
      new_pilot_angle[pilot_get_idx] = tagged Valid angle;

      pilot_angle <= new_pilot_angle;
      if(`DEBUG_CHANNEL_ESTIMATOR == 1)
         begin
            $write("pilots angle idx %d ",pilot_get_idx);
            fxptWrite(5,angle);
            $display("");
         end
     
      // for magnitude
      FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec) factor <- inv_sq_root.response.get();
      Vector#(CEstPNo,Maybe#(FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec))) new_pilot_mag = pilot_mag;
      new_pilot_mag[pilot_get_idx] = tagged Valid factor;
      
      pilot_mag <= new_pilot_mag;
      if(`DEBUG_CHANNEL_ESTIMATOR == 1)
         begin
            $write("pilots mag idx %d ",pilot_get_idx);
            fxptWrite(5,factor);
            $display("");
         end
         
      // common state update
      if (pilot_get_idx != fromInteger(valueOf(CEstPNo) - 1)) // can start calculating diff
         begin
            FixedPoint#(CEstIPrec,CEstFPrec) new_angle_diff = getAngleDiff(fromMaybe(?,pilot_angle[pilot_get_idx+1]), angle);
            angle_diff[pilot_get_idx] <= tagged Valid new_angle_diff;
            FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec) new_mag_diff = fromMaybe(?,pilot_mag[pilot_get_idx+1]) - factor;
            mag_diff[pilot_get_idx] <= tagged Valid new_mag_diff;
         end
      pilot_get_idx <= pilot_get_idx - 1;      
   endrule
   
   // interpolate the pilot estimations to get data subcarrier
   rule interpolate(can_interpolate && isValid(angle_diff[affine_idx]) && isValid(mag_diff[affine_idx]));
      // for angle
      FixedPoint#(CEstIPrec,CEstFPrec) base_angle = fromMaybe(?,pilot_angle[affine_idx]);
      FixedPoint#(CEstIPrec,CEstFPrec) diff_angle = fromMaybe(?,angle_diff[affine_idx]);
      FixedPoint#(CEstIPrec,CEstFPrec) interpolate_angle = base_angle +affine_coef *  diff_angle;
      
      angle_q.enq(interpolate_angle);
      if(`DEBUG_CHANNEL_ESTIMATOR == 1)
         begin
            $write("interpolate angle idx %d ",interpolate_idx);
            fxptWrite(5,interpolate_angle);
            $display("");
         end
      
      // for magnitude
      FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec) base_mag = fromMaybe(?,pilot_mag[affine_idx]);
      FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec) diff_mag = fromMaybe(?,mag_diff[affine_idx]);
      FixedPoint#(TAdd#(CEstIPrec,CEstFPrec),CEstFPrec) interpolate_mag = base_mag + fxptSignExtend(affine_coef) *  diff_mag;
      
      mag_q.enq(interpolate_mag);
      if(`DEBUG_CHANNEL_ESTIMATOR == 1)
         begin
            $write("interpolate magnitude idx %d ",interpolate_idx);
            fxptWrite(5,interpolate_mag);
            $display("");
         end
         
      // common state update
      interpolate_idx <= interpolate_idx - 1;
      if (interpolate_idx == 0) // last one
         can_interpolate <= False;
   endrule
                                               
                                               
   // calculate adjustement
   rule calculate_adjustment_put(True);
      cos_and_sin.putAngle(angle_q.first);
      angle_q.deq;
   endrule

   // calculate adjustement
   rule calculate_adjustment_get(True);      
      // angle
      CosSinPair#(CEstIPrec,CEstFPrec) cos_sin_pair <- cos_and_sin.getCosSinPair;
      FPComplex#(CEstIPrec,CEstFPrec) angle_adjustment = cmplx(cos_sin_pair.cos,cos_sin_pair.sin);
      angle_adjust_q.enq(angle_adjustment);
      
      // mag
      FPComplex#(TAdd#(1,TAdd#(TAdd#(CEstIPrec,CEstFPrec),CEstIPrec)),TAdd#(CEstFPrec,CEstFPrec)) mag_adjusted = fpcmplxScale(mag_q.first, out_reg.data[out_read_idx]);
      FPComplex#(CEstIPrec,CEstFPrec) mag_adjusted_trunc = fpcmplxTruncate(mag_adjusted);
      out_read_idx <= out_read_idx - 1;
      mag_q.deq;
      mag_adjusted_q.enq(mag_adjusted_trunc);
   endrule
   
   // perform correction
   rule correct(True);
      let o_data     = out_reg.data;
      let adj_data   = mag_adjusted_q.first * angle_adjust_q.first; // adjust according to pilot
      if(`DEBUG_CHANNEL_ESTIMATOR == 1)
         begin
            $write("ChannelEstMod %d: ",out_write_idx);
            fpcmplxWrite(5, o_data[out_write_idx]);
            $write(" -> ");
            fpcmplxWrite(5,adj_data);
            $write(" magnitude adjusted ");
            fpcmplxWrite(5, mag_adjusted_q.first);
            $write(" * angle correction cmplx:");
            fpcmplxWrite(5, angle_adjust_q.first);
            $display("");
         end
      o_data[out_write_idx] = adj_data;    
      let o_mesg = Mesg{control:out_reg.control, data:o_data};
      mag_adjusted_q.deq;
      angle_adjust_q.deq;
      out_write_idx <= out_write_idx - 1; // finish one output
      out_reg <= o_mesg; // update on entry
      if (out_write_idx == 0)
         can_write_out_symbol <= True;
   endrule

   interface Put in;
      method Action put(ChannelEstimatorMesg#(ctrl_t,CEstInN,CEstIPrec,CEstFPrec) iMesg)
         if (can_read_in_symbol);
	 let i_ctrl = iMesg.control;
	 let i_data = iMesg.data;
	 let p_ctrl = resetPilot(i_ctrl);
         let r_plt  = tpl_1(p_ctrl); // need to reset pilot_lfsr
         let u_plt  = tpl_2(p_ctrl); // need to update pilot_lfsr
	 let i_pilot_lfsr = r_plt ? init_seq : pilot_lfsr;
	 let feedback = genXORFeedback(prbs_mask,i_pilot_lfsr);
 	 Bit#(CEstPSzSub1) t_pilot_lfsr = tpl_2(split(i_pilot_lfsr));
	 let new_pilot_lfsr = {t_pilot_lfsr,feedback};
	 let split_data = splitPilot(i_data, feedback);
         let new_pilot_eval = map(cmplxConj, tpl_1(split_data)); // conj of pilot as inverse
         let o_data = tpl_2(split_data);
	 let o_mesg = Mesg{ control:i_ctrl, data: o_data };

         if (u_plt)
            begin
	       pilot_lfsr <= new_pilot_lfsr;
            end
	 out_reg    <= o_mesg;
         can_read_in_symbol <= False;
         can_est_pilot <= True;
         can_interpolate <= True;
         out_read_idx <= max_idx;
         out_write_idx <= max_idx;     
         interpolate_idx <= max_idx;
         pilot_eval <= new_pilot_eval;
         pilot_put_idx <= fromInteger(valueOf(CEstPNo)-1);
         pilot_get_idx <= fromInteger(valueOf(CEstPNo)-1);
         pilot_mag <= replicate(tagged Invalid);
         pilot_angle <= replicate(tagged Invalid);
         mag_diff <= replicate(tagged Invalid);
         angle_diff <= replicate(tagged Invalid);
         if(`DEBUG_CHANNEL_ESTIMATOR == 1)
            begin
               $display("ChannelEst new message:%d",r_plt);
               $display("ChannelEst input data:");
               for(Integer i=0; i<valueOf(CEstInN) ; i=i+1)
                  begin
                     Int#(TAdd#(CEstIPrec,CEstFPrec)) img = unpack(pack(i_data[i].img));
                     Int#(TAdd#(CEstIPrec,CEstFPrec)) rel = unpack(pack(i_data[i].rel));
                     $display("ChannelEstIn:%d:%d:%d",i,rel,img);
                  end         
            end
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(DemapperMesg#(ctrl_t,CEstOutN,CEstIPrec,CEstFPrec)) get()
         if (can_write_out_symbol);
         can_write_out_symbol <= False;
         can_read_in_symbol <= True;
   
         if(`DEBUG_CHANNEL_ESTIMATOR == 1)
            begin
               for(Integer i=0; i<valueOf(CEstOutN) ; i=i+1)
                  begin
                     Int#(TAdd#(CEstIPrec,CEstFPrec)) img = unpack(pack(out_reg.data[i].img));
                     Int#(TAdd#(CEstIPrec,CEstFPrec)) rel = unpack(pack(out_reg.data[i].rel));
                     $display("ChannelEstOut:%d:%d:%d:%d",inverseMapping(i),i,rel,img);
                  end 
            end
         
         return out_reg;
      endmethod
   endinterface
endmodule


// module mkMagnitudeAdjustChannelEstimator#(function Tuple2#(Bool,Bool) 
//                                  resetPilot(ctrl_t ctrl),
//                                  function Tuple2#(Symbol#(p_no,i_prec,f_prec),
//                                             Symbol#(out_n,i_prec,f_prec)) 
//                                  splitPilot(Symbol#(in_n,i_prec, f_prec) in,
//                                          Bit#(1) p),
//                                  function Vector#(out_n,Tuple2#(Bit#(TLog#(p_no)),FixedPoint#(TAdd#(i_prec,f_prec),f_prec)))
//                                  mapPilot(Vector#(in_n,Tuple2#(Bit#(TLog#(p_no)),FixedPoint#(TAdd#(i_prec,f_prec),f_prec))) in),
//                                  function Integer inverseMapping(Integer i),
//                                  Bit#(p_sz) prbsMask,
//                                  Bit#(p_sz) initSeq,
//                                  Vector#(p_no,Integer) pilotLocs)
//    (ChannelEstimator#(ctrl_t,in_n,out_n,i_prec,f_prec))
//    provisos (Bits#(ctrl_t, ctrl_sz),
//              Add#(1,xxA,p_sz),
//              Add#(xxA,1,p_sz),
//              Log#(out_n,out_sz),
//              Log#(p_no,p_sz),
//              Arith#(FixedPoint#(i_prec,f_prec)),
//              Add#(1,xxB,i_prec),
//              Add#(4,xxC,TAdd#(32,f_prec)),
//              Add#(i_prec,f_prec,TAdd#(i_prec,f_prec)),
//              RealLiteral#(FixedPoint::FixedPoint#(TAdd#(i_prec, i_prec), f_prec)),
//              Arith#(FixedPoint::FixedPoint#(TAdd#(i_prec, i_prec), f_prec)),
//              Add#(1, TAdd#(TAdd#(TAdd#(i_prec, i_prec), i_prec), TAdd#(f_prec,f_prec)), 
//                        TAdd#(TAdd#(1, TAdd#(TAdd#(i_prec, i_prec), i_prec)),TAdd#(f_prec, f_prec))),
//              Add#(TAdd#(TAdd#(i_prec, i_prec), f_prec), TAdd#(i_prec, f_prec), 
//                      TAdd#(TAdd#(TAdd#(i_prec, i_prec), i_prec), TAdd#(f_prec, f_prec))),
//              Add#(a__, TAdd#(i_prec, f_prec), TAdd#(TAdd#(1, TAdd#(TAdd#(i_prec, i_prec), i_prec)), TAdd#(f_prec, f_prec))),
//              Add#(b__, i_prec, TAdd#(1, TAdd#(TAdd#(i_prec, i_prec), i_prec))),
//              Arith#(FixedPoint::FixedPoint#(TAdd#(1, TAdd#(TAdd#(i_prec, i_prec),i_prec)), TAdd#(f_prec, f_prec))),
//              Add#(TAdd#(i_prec, i_prec), i_prec, TAdd#(TAdd#(i_prec, i_prec), i_prec)),
//              Add#(1, TAdd#(TAdd#(i_prec, i_prec), i_prec), TAdd#(1, TAdd#(TAdd#(i_prec,i_prec), i_prec))),
//              Add#(f_prec, f_prec, TAdd#(f_prec, f_prec)),
           



//              Add#(1,axx,TAdd#(i_prec,f_prec)), 
//              Add#(1, cxx, TAdd#(TAdd#(i_prec, f_prec), f_prec)),
//              Add#(TAdd#(i_prec, f_prec), f_prec, TAdd#(TAdd#(i_prec, f_prec), f_prec)),
//              RealLiteral#(FixedPoint::FixedPoint#(TAdd#(i_prec, f_prec), f_prec)),
//              Add#(TAdd#(i_prec, f_prec), TAdd#(i_prec, f_prec), TAdd#(TAdd#(i_prec, i_prec), TAdd#(f_prec,f_prec))),
//              Add#(dxx, TAdd#(1, TAdd#(i_prec, i_prec)), TAdd#(i_prec, f_prec)),
//              Arith#(FixedPoint::FixedPoint#(TAdd#(1, TAdd#(i_prec, i_prec)), TAdd#(f_prec,f_prec))),
//              Add#(i_prec, i_prec, TAdd#(i_prec, i_prec)),
//              //Add#(lxx, TAdd#(TAdd#(1, TAdd#(i_prec, i_prec)), TAdd#(f_prec, f_prec)),TAdd#(TAdd#(i_prec, i_prec), TAdd#(f_prec, f_prec))),
//              Add#(1, TAdd#(TAdd#(i_prec, i_prec), TAdd#(f_prec, f_prec)), TAdd#(TAdd#(1, TAdd#(i_prec,i_prec)), TAdd#(f_prec,f_prec))),
//              Add#(1, TAdd#(i_prec, i_prec), TAdd#(1, TAdd#(i_prec, i_prec))),
//              Add#(jxx, TAdd#(TAdd#(1, TAdd#(i_prec, i_prec)), TAdd#(f_prec, f_prec)),TAdd#(TAdd#(i_prec, f_prec), TAdd#(f_prec, f_prec))),
//              Add#(kxx, TAdd#(TAdd#(i_prec, f_prec), f_prec), TAdd#(TAdd#(i_prec,f_prec), TAdd#(f_prec, f_prec))),
//              Add#(TAdd#(TAdd#(i_prec, f_prec), f_prec), TAdd#(i_prec, f_prec),TAdd#(TAdd#(TAdd#(i_prec, f_prec), i_prec), TAdd#(f_prec, f_prec))),
//              Arith#(FixedPoint::FixedPoint#(TAdd#(1, TAdd#(TAdd#(i_prec, f_prec),TAdd#(i_prec, f_prec))), TAdd#(f_prec, f_prec))),
//              Add#(TAdd#(i_prec, f_prec), i_prec, TAdd#(TAdd#(i_prec, f_prec), i_prec)),
//              Add#(fxx, i_prec, TAdd#(1, TAdd#(TAdd#(i_prec, f_prec), TAdd#(i_prec,f_prec)))),
//              Add#(gxx, TAdd#(i_prec, f_prec), TAdd#(TAdd#(1, TAdd#(TAdd#(i_prec,f_prec), TAdd#(i_prec, f_prec))), TAdd#(f_prec, f_prec))),
//              Add#(1, TAdd#(TAdd#(i_prec, f_prec), i_prec), TAdd#(1, TAdd#(TAdd#(i_prec,f_prec), i_prec))),
//              Arith#(FixedPoint::FixedPoint#(TAdd#(1, TAdd#(TAdd#(i_prec, f_prec),i_prec)), TAdd#(f_prec, f_prec))),
//              Add#(1, TAdd#(TAdd#(TAdd#(i_prec, f_prec), i_prec), TAdd#(f_prec,f_prec)), TAdd#(TAdd#(1, TAdd#(TAdd#(i_prec, f_prec), i_prec)),TAdd#(f_prec, f_prec))),
//              Add#(exx, i_prec, TAdd#(1, TAdd#(TAdd#(i_prec, f_prec), i_prec))),
//              Add#(hxx, TAdd#(i_prec, f_prec), TAdd#(TAdd#(1, TAdd#(TAdd#(i_prec,f_prec), i_prec)), TAdd#(f_prec, f_prec))),

//                           Literal#(FixedPoint::FixedPoint#(i_prec, f_prec))

//             );
   
//    // constants
//    Integer pilot_no = valueOf(p_no);  // no. pilot
//    Integer out_no   = valueOf(out_n); // no. output values
//    Bit#(out_sz) maxIdx = fromInteger(out_no-1);

                           
//    // state elements
//    Reg#(Bool)                  setupComplete <- mkReg(True);
//    Reg#(Bool)                  compComplete  <- mkReg(True);
//    Reg#(Bit#(out_sz))                   outIdx <- mkReg(?)();
//    Reg#(Bit#(p_sz))                  pilotIdxSetup <- mkReg(?)();
//    Reg#(Bit#(p_sz))                  pilotIdxSetupWrite <- mkReg(?)();
//    Reg#(Bit#(p_sz))                  pilotLFSR <- mkReg(?)();
//    Reg#(Symbol#(p_no,i_prec,f_prec)) pilotEval <- mkReg(?)(); 
//    Reg#(DemapperMesg#(ctrl_t,out_n,i_prec,f_prec))  outReg <- mkReg(?)(); // probably can get rid of this guy...
//    FIFO#(DemapperMesg#(ctrl_t,out_n,i_prec,f_prec))   outQ <- mkSizedFIFO(2);
//    Vector#(p_no,Reg#(Maybe#(FixedPoint#(TAdd#(i_prec,f_prec), f_prec)))) adjustValues <- replicateM(mkReg(tagged Invalid)); 
//    InverseSqRoot#(TAdd#(i_prec,f_prec),f_prec) invSqRoot <- mkSimpleInverseSqRoot;  
//    let splitRes = mapPilot(determineAffineCoefficients(pilotLocs()));
//    Vector#(out_n,Tuple2#(Bit#(TLog#(p_no)),FixedPoint#(TAdd#(i_prec,f_prec),f_prec))) affineCoefs = splitRes;

//    rule setupPilots(!setupComplete);
//      pilotIdxSetup <= pilotIdxSetup - 1;
//      if(pilotIdxSetup == 0)
//        begin
//          setupComplete <= True;
//        end
       
//        FixedPoint#(TAdd#(i_prec,f_prec),TAdd#(f_prec,f_prec)) mag = fxptZeroExtend(fpcmplxModSq(pilotEval[pilotIdxSetup]));
//        FixedPoint#(TAdd#(i_prec,f_prec),f_prec) shortMag = fxptTruncate(mag);
//        invSqRoot.request.put(shortMag);
//    endrule

//    rule setupPilotsWrite;
//      pilotIdxSetupWrite <= pilotIdxSetupWrite - 1;
//      FixedPoint#(TAdd#(i_prec,f_prec),f_prec) factor <- invSqRoot.response.get();
//      adjustValues[pilotIdxSetupWrite] <= tagged Valid factor;
//      FPComplex#(TAdd#(1,TAdd#(TAdd#(i_prec,f_prec),i_prec)),TAdd#(f_prec,f_prec)) scale = fpcmplxScale(factor,pilotEval[pilotIdxSetupWrite]);
//      FPComplex#(i_prec,f_prec) scaleTrunc = fpcmplxTruncate(scale); 
//      pilotEval[pilotIdxSetupWrite] <= scaleTrunc;
//    endrule
   
 

//    rule process(adjustValues[tpl_1(affineCoefs[outIdx])] matches tagged Valid .adjust1 &&& adjustValues[1+tpl_1(affineCoefs[outIdx])] matches tagged Valid .adjust2 &&& !compComplete);
//       let oData     = outReg.data;

//       $write("ChannelEstIn %d: ",outIdx);
//       fpcmplxWrite(5, oData[outIdx]);
//       $write(" * PilotIdx %d:", tpl_1(affineCoefs[outIdx]));
//       fpcmplxWrite(5, pilotEval[tpl_1(affineCoefs[outIdx])]);
//       $display("");
//       oData[outIdx] = oData[outIdx] * pilotEval[tpl_1(affineCoefs[outIdx])]; // adjust according to pilot angle

//       $write("ChannelEst Angle %d: ",outIdx);
//       fpcmplxWrite(5, oData[outIdx]);
//       $write("   ChannelAdjust1: " );
//       fxptWrite(5, adjust1);
//       $write("  ChannelAdjust2: " );
//       fxptWrite(5, adjust2);
//       $write("  AdjustDelta: " );
//       fxptWrite(5, adjust2 - adjust1);
//       $write("  Affine: " );
//       fxptWrite(5, tpl_2(affineCoefs[outIdx]));
//       $display("");

//       FPComplex#(TAdd#(1,TAdd#(TAdd#(i_prec,f_prec),i_prec)),TAdd#(f_prec,f_prec)) scale = fpcmplxScale((adjust1 +  (adjust2 - adjust1) * tpl_2(affineCoefs[outIdx])), oData[outIdx]);
//       FPComplex#(i_prec,f_prec) scaleTrunc = fpcmplxTruncate(scale);
//       oData[outIdx] = scaleTrunc;       

//       $write("ChannelEst Result %d: ",outIdx);
//       fpcmplxWrite(5, oData[outIdx]);
//       $display("");
//       let oMesg = Mesg{control:outReg.control, data:oData};
//       outIdx <= outIdx - 1; // finish one output
//       outReg <= oMesg; // update on entry
//       if (outIdx == 0)
//          begin
//             outQ.enq(oMesg);
//             compComplete <= True;
//          end
//    endrule

//    interface Put in;
//       method Action put(ChannelEstimatorMesg#(ctrl_t,in_n,i_prec,f_prec) iMesg)
//          if (compComplete && setupComplete);
// 	 let iCtrl = iMesg.control;
// 	 let iData = iMesg.data;
// 	 let pCtrl = resetPilot(iCtrl);
//          let rPlt  = tpl_1(pCtrl); // need to reset pilotLFSR
//          let uPlt  = tpl_2(pCtrl); // need to update pilotLFSR
// 	 let iPilotLFSR = rPlt ? initSeq : pilotLFSR;
// 	 let feedback = genXORFeedback(prbsMask,iPilotLFSR);
// 	 Bit#(xxA) tPilotLFSR = tpl_2(split(iPilotLFSR));
// 	 let newPilotLFSR = {tPilotLFSR,feedback};
// 	 let splitData = splitPilot(iData, feedback);
//          let newPilotEval = map(cmplxConj, tpl_1(splitData)); // conj of pilot as inverse
//          let oData = tpl_2(splitData);
// 	 let oMesg = Mesg{ control:iCtrl, data: oData };
// 	 outReg    <= oMesg;
//          writeVReg(adjustValues, replicate(tagged Invalid));
//          pilotEval <= newPilotEval;
//          if (uPlt)
//             begin
// 	       pilotLFSR <= newPilotLFSR;
//             end
//          setupComplete <= False;
//          compComplete <= False;
//          outIdx <= maxIdx;
//          pilotIdxSetup <= fromInteger(valueof(p_no)-1);
//          pilotIdxSetupWrite <= fromInteger(valueof(p_no)-1);
//          $display("ChannelEst input data:");
//          for(Integer i=0; i<valueOf(CEstInN) ; i=i+1)
//             begin
//                $write("ChannelEstIn %d: ",i);
//                fpcmplxWrite(5,iData[i]);
//                $display("");
//             end         
// //          $display("Pilots Eval:");
// //          for(Integer i=0; i<pilot_no ; i=i+1)
// //             begin
// //                $write("%d: ",i);
// //                fpcmplxWrite(5,newPilotEval[i]);
// //                $display("");
// //             end
//       endmethod
//    endinterface

//    interface Get out;
//      method ActionValue#(DemapperMesg#(ctrl_t,out_n,i_prec,f_prec)) get(); 
//        outQ.deq;

//        for(Integer i=0; i<valueOf(CEstOutN) ; i=i+1)
//          begin
//            $write("ChannelEstOut %d->%d: ",inverseMapping(i),i);
//            fpcmplxWrite(5,outQ.first.data[i]);
//            $display("");
//          end 
       
//        return outQ.first;
//      endmethod
//    endinterface
// endmodule

