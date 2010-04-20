import Connectable::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import FShow::*;
import Probe::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/reversal_buffer.bsh"
`include "asim/provides/librl_bsv.bsh"

/////////////////////////////////////////////////////////
// Begin of BCJR Module 

(*synthesize*)
module mkIBCJR (IViterbi);
   
   // magic sizing variable 
   Bit#(TMul#(`REVERSAL_BUFFER_SIZE,4)) bigFIFO = 0;

   Reg#(Bit#(32)) clockCycles <- mkReg(0);

   // BCJR Frontend
   BranchMetricUnit bmu <- mkBranchMetricUnit;
   Reg#(BCJRBitId) bitId <- mkReg(0);
   FIFOF#(VBranchMetricUnitOut) bmuForwardOut <- mkSizedBRAMFIFOF(bigFIFO);

   ForwardPath forwardPath <- mkForwardPath;

   let pathMetricEstimate <- mkPathMetricEstimate(forwardPath);

   BackwardPath backwardPath <- mkBackwardPath(
      regToReadOnly(clockCycles),
      pathMetricEstimate);

   //Decision Blocks
   DecisionUnit decisionUnit <- mkDecisionUnit;

   rule tickClock;
     clockCycles <= clockCycles + 1;
   endrule

   Reg#(Bool) bmuPushLast <- mkReg(False);
   Reg#(Bool) decisionReInit <- mkReg(True);
   Reg#(Bit#(`REVERSAL_BUFFER_SIZE)) revResetCounter <- mkReg(0);

   // Some diagnostic
   if(`DEBUG_BCJR == 1)
     begin
       rule diagnostic;
         //$display("BCJR Diganostic bmuForwardOut: ", fshow(bmuForwardOut));
         //$display("BCJR Diganostic bmuReverseOut: ", fshow(bmuReverseOut));
         //$display("BCJR Diganostic backwardPathLast: ", fshow(backwardPathLast));
         //$display("BCJR Diganostic backwardsInit: ", fshow(backwardsInit));
       endrule
     end

   // may need to push through one last last, as we no long push zeros...


   rule feedPMUForward;
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: pushing bmu data to forward unit");
       end
     bmuForwardOut.deq;
     forwardPath.in.put(PathMetricUnitIn{branchMetric: bmuForwardOut.first, initPathMetric: initPathMetricZero()});
   endrule

   rule bmuSplit(!bmuPushLast);
     let branchMetric <- bmu.out.get;
     match {.ctrl, .data} = branchMetric;
     bmuForwardOut.enq(branchMetric);
     //Check for end of coding, these things will get swizzled 
     //by the reversal, so we will track them externally and patch things on the outbound.     
   
     if(ctrl) // This is the last
       begin    
         if(`DEBUG_BCJR == 1)
            begin
              $display("BCJR: BMU push last next cycle");
            end
  
         bmuPushLast <= True; // Push last next cycle
       end    

     //Generate backward rst_need here. 
     let revCounterNext = (revResetCounter + 1 == reversalGranularity)?0:revResetCounter+1;
     Bool pushReset = (revResetCounter == 0); // These will all get flipped to the end of the blocks
     bitId <= bitId + 1;

     if(pushReset) 
       begin
         if(`DEBUG_BCJR == 1)
           begin
             $display("BCJR BMU pushes reset at bitId: %d", bitId);
           end
       end

     revResetCounter <= revCounterNext;
     //Strip out the last ctrl for the revBuffer.  We'll manage it explicitly out of band.
     backwardPath.in.put(tuple2(BCJRBackwardCtrl{last:False, bitId: bitId},
                                tuple2(bitId,(tuple2(pushReset,data)))));
   endrule


   rule bmuReversePushLast(bmuPushLast);
     bitId <= 0;
     revResetCounter <= 0;
     bmuPushLast <= False;
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR initial push last, total bits: %d @ %d", bitId, clockCycles);
       end

     backwardPath.in.put(tuple2(BCJRBackwardCtrl{last:True, bitId: ~0},?));
   endrule
  
   let isLast = tpl_1(peekGet(backwardPath.out)).last;

   // Due to the path metric off by one issue, this stuff now has to be slightly
   // modified. 
   rule feedDecisionUnit(!isLast && !decisionReInit);
     let backwardProbs <- backwardPath.out.get();
     let forwardProbs <- forwardPath.out.get();
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: Decision Unit is being fed bitId %d",tpl_1(peekGet(backwardPath.out)).bitId);
       end

     decisionUnit.in.put(tuple2(tpl_2(backwardProbs),forwardProbs));
   endrule

   rule feedDecisionUnitEatFirst(!isLast && decisionReInit);
     let backwardProbs <- backwardPath.out.get();

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: Decision Unit Clear Backwards Last");
       end

     decisionReInit <= False;
   endrule

   rule feedDecisionUnitEatLast(isLast && decisionReInit);
     let backwardProbs <- backwardPath.out.get();

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: Decision Unit Clear Extra Backward bit @ %d", clockCycles);
       end
   endrule

   rule feedDecisionUnitReplaceFirst(isLast && !decisionReInit);
     let forwardProbs <- forwardPath.out.get();
     decisionReInit <= True;
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: Decision Unit is being fed final bitId");
       end
     // assert that this bit is the last one...
     if(!tpl_1(forwardProbs)) 
       begin
         $display("BCJR: Decision Unit expected last forward, but was not marked as such");
         $finish;
       end
     decisionUnit.in.put(tuple2(tuple2(False,unpack(0)),forwardProbs));
   endrule

   //mkConnection(pmu.out, tbu.in);

   method Action putData (VInType in_data);
      bmu.in.put(in_data);
   endmethod

   method ActionValue#(VOutType) getResult();
      let res <- decisionUnit.out.get();
      return res;
   endmethod
   
endmodule

module mkConvDecoder#(function Bool decodeBoundary(ctrl_t ctrl))
   (Viterbi#(ctrl_t,n2,n))
   provisos(Log#(n2,ln2),
            Log#(n,ln),
            Bits#(ctrl_t, ctrl_sz));

   Integer ctrl_q_sz = 4 * valueof(`REVERSAL_BUFFER_SIZE);

   let bcjr <- mkIBCJR;
   let decoder <- mkConvDecoderInstance(decodeBoundary, ctrl_q_sz, bcjr);
   return decoder;
endmodule

