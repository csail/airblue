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


typedef Tuple2#(BCJRBackwardCtrl,Tuple2#(BCJRBitId,VBranchMetricUnitOut)) BackwardPathIn;
typedef Tuple2#(BCJRBackwardCtrl,VPathMetricUnitOut) BackwardPathOut;


interface BackwardPath;
   interface Put#(BackwardPathIn) in;
   interface Get#(BackwardPathOut) out;
endinterface


module mkBackwardPath (
      ReadOnly#(Bit#(32)) clockCycles,
      Get#(Vector#(VTotalStates,VPathMetric)) pathMetricEstimate,
      BackwardPath ifc);

   // magic sizing variable 
   Bit#(TMul#(`REVERSAL_BUFFER_SIZE,4)) bigFIFO = 0;

   // Reverse Path Blocks
   ReversalBuffer#(Tuple2#(BCJRBitId,VBranchMetricUnitOut),BCJRBackwardCtrl,`REVERSAL_BUFFER_SIZE) revBufferInitial <- mkReversalBuffer("BCJR revInitial");
   ReversalBuffer#(VPathMetricUnitOut,BCJRBackwardCtrl,`REVERSAL_BUFFER_SIZE) revBufferFinal  <- mkReversalBuffer("BCJR revFinal");
   PathMetricUnit pmuBackwardEstimator <- mkPathMetricUnit("BCJR PMU Backwards Estimator",getPMUOutBCJRBackward,getBranchMetricBackward);
   PathMetricUnit pmuBackward         <- mkPathMetricUnit("BCJR PMU Backwards",getPMUOutBCJRBackward,getBranchMetricBackward);
   Reg#(Bool) firstBlock <- mkReg(True);
   FIFOF#(BackwardPathCtrl) bmuReverseOut <- mkSizedBRAMFIFOF(bigFIFO);
   FIFOF#(BCJRBackwardCtrl) backwardPathLast <- mkSizedBRAMFIFOF(bigFIFO); // Must cover latency of decision unit   
   
   Reg#(Bool) pmuBackwardReInit <- mkReg(True);
   FIFOF#(PMUBackwardIntialState) backwardsInit <- mkSizedFIFOF(8);


   Reg#(Bit#(32)) pmuESTEnq <- mkReg(0);
   //Rev Buffer data 
   let revBufferInitialResult = peekGet(revBufferInitial.outputData);
   match {.revBufferCtrl, .revBufferPayload} = revBufferInitialResult; 
   match {.revBufferId, .revBufferInitialPayload } = revBufferPayload;
   let revBufferInitialLast = revBufferCtrl.last; 
   let revBufferInitialId = revBufferCtrl.bitId; 

   // This reg holds the initial values of the PMU for a cycle. 

   rule backwardsPMUEstimator(!revBufferInitialLast);
     let revBufferResult <- revBufferInitial.outputData.get;
     match {.need_rst, .bmuOut} = revBufferInitialPayload;

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR backwardsPMUEstimator fires: %d", clockCycles);
       end

     // Check bitIds 
     if(revBufferId != revBufferInitialId) 
       begin
         $display("BCJR BMU Ids do not match: ctrl: %d payload: %d", revBufferInitialId ,revBufferId);
         $finish;
       end

     // need to strip out the original last
     // use revResetCounter  
     //keep last around, we'll need it for the final reversal...
     if(!firstBlock) // feed the Estimator...
       begin
         if(`DEBUG_BCJR == 1)
           begin
             $display("BCJR Putting data into PMU Backward Estimator: bitId: %d need_rst: %h", revBufferInitialId, need_rst);
           end

         pmuBackwardEstimator.in.put(PathMetricUnitIn{branchMetric: revBufferInitialPayload, initPathMetric: peekGet(pathMetricEstimate)});
       end
     
     if(need_rst)
       begin
         if(!firstBlock)
           begin
             if(`DEBUG_BCJR == 1)
               begin
	         $display("BCJR Backwards Estimator: ReInit pmuESTEnq requested: %d ",pmuESTEnq+1);
               end

             pmuESTEnq <= pmuESTEnq + 1;
             backwardsInit.enq(PMUEst);
           end
         else 
           begin
             if(`DEBUG_BCJR == 1)
               begin
                 $display("BCJR PMUEst firstBlock @ %d", clockCycles);
               end
           end

         let estimate <- pathMetricEstimate.get();
         firstBlock <= False;
       end
    
     // push branchMetric into the buffer FIFO
     // this one will track the true last.
     
     bmuReverseOut.enq(BackwardPathCtrl{backwardCtrl: revBufferCtrl,metric:revBufferInitialPayload});
   endrule



   Reg#(Bit#(32)) defaultEnq <- mkReg(0);
   // This is the end of the packet...  reset state, and push one last initial value.
   // this last should only occur
   rule backwardsPMUEstimatorDecodeEnd(revBufferInitialLast);
     firstBlock <= True;
     let revBufferResult <- revBufferInitial.outputData.get; 
     defaultEnq <= defaultEnq + 1;
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR Backwards Estimator: ReInit Default requested %d", defaultEnq + 1);
       end

     backwardsInit.enq(Default);
     // feed in need reset and a default vector
     // I believe 0 means no error for branch metric...
     // This may be introduce an extra token :(
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR PMU Estimator Decode End Fires @ %d", clockCycles);
       end

     bmuReverseOut.enq(BackwardPathCtrl{backwardCtrl:BCJRBackwardCtrl{last:True, bitId: ~0},metric:?});
   endrule

   let pmuEstimatePeek = peekGet(pmuBackwardEstimator.out);
   match {.need_rstPMUEst, .pmuEst} = pmuEstimatePeek;
   match {.need_rstBackward, .bmuBackward} = bmuReverseOut.first.metric;

   // get rid of non-last stuff. We do not need it.
   rule backwardsPMUEstimatorDiscard(!need_rstPMUEst);
     let pmuEstimate <- pmuBackwardEstimator.out.get;
   endrule


   // no ref to pmu est here....
   rule backwardsPMUNormal(!bmuReverseOut.first.backwardCtrl.last && !pmuBackwardReInit);
     bmuReverseOut.deq;
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR Putting data into PMU Normal: bitId(Norm): %d need_rst: %h", 
           bmuReverseOut.first.backwardCtrl.bitId,need_rstBackward);
         $display("BCJR PMU Normal got bitId %d rstBMU: %h", 
            bmuReverseOut.first.backwardCtrl.bitId, tpl_1(bmuReverseOut.first.metric));
       end
  
      // should use the est rst...
      // using reset est: tuple2(need_rstPMUEst,tpl_2(bmuReverseOut.first.metric))
      // not: bmuReverseOut.first.metric
      pmuBackward.in.put(PathMetricUnitIn{branchMetric:  bmuReverseOut.first.metric, 
                                          initPathMetric: ?});
      backwardPathLast.enq(bmuReverseOut.first.backwardCtrl);

      if(need_rstBackward) 
        begin

        if(`DEBUG_BCJR == 1)
          begin
            $display("PMUNormal ReInit needs to be processed at bit %d", bmuReverseOut.first.backwardCtrl.bitId);
          end

          pmuBackwardReInit <= True;
        end
   endrule

  
   Reg#(Bit#(32)) pmuESTDeq <- mkReg(0);
   // reinit from pmuEST
   rule backwardsPMUReInit(!bmuReverseOut.first.backwardCtrl.last && need_rstPMUEst && 
                           pmuBackwardReInit && backwardsInit.first == PMUEst);
      let pmuEstimate <- pmuBackwardEstimator.out.get;
      backwardsInit.deq;

      if(`DEBUG_BCJR == 1)
        begin
          $display("BCJR handling PMU Est ReInit: bitId(Norm): %d count: %d", bmuReverseOut.first.backwardCtrl.bitId, pmuESTDeq + 1);
        end

      pmuESTDeq <= pmuESTDeq + 1;
      pmuBackwardReInit <= False;
      bmuReverseOut.deq;

      if(`DEBUG_BCJR == 1)
        begin
          $display("BCJR PMU Normal got bitId %d rstPMUEst: %h rstBMU: %h", bmuReverseOut.first.backwardCtrl.bitId, need_rstPMUEst, tpl_1(bmuReverseOut.first.metric));
          $display("BCJR PMU Normal Initial Vector: ", fshow(tpl_1(unzip(pmuEst))));
        end

      pmuBackward.in.put(PathMetricUnitIn{branchMetric:  bmuReverseOut.first.metric, 
                                          initPathMetric: tpl_1(unzip(pmuEst))});
      backwardPathLast.enq(bmuReverseOut.first.backwardCtrl);
   endrule

   // check for deadlock condition
   rule checkDefaultPMU(backwardsInit.first == Default && need_rstPMUEst);
     $display("BCJR Expecting Default, but pmuBackward has a valid intialization");
     $finish;
   endrule



   Reg#(Bit#(32)) defaultDeq <- mkReg(0);
   // reinit from default. This is probably not the best place to handle the reinit...  
   // We probably are better padding out many zeros.
   // What will do here in the padding case is to remove the padding block, as it is no longer needed. 
   rule backwardsPMUReInitDefault(!bmuReverseOut.first.backwardCtrl.last && 
                                  pmuBackwardReInit && backwardsInit.first == Default);

      if(`DEBUG_BCJR == 1)
        begin
          $display("BCJR handling PMU ReInit Default bitId(Norm): %d count: %d", 
               bmuReverseOut.first.backwardCtrl.bitId,
               defaultDeq + 1);
        end

      defaultDeq <= defaultDeq + 1;
      pmuBackwardReInit <= False;
      bmuReverseOut.deq;
      backwardsInit.deq;

      if(`DEBUG_BCJR == 1)
        begin
          $display("BCJR PMU Normal got bitId %d rstBMU: %h", bmuReverseOut.first.backwardCtrl.bitId, tpl_1(bmuReverseOut.first.metric));
          $display("BCJR PMU Normal Initial Vector: ", initPathMetricZero());
        end
     
      pmuBackward.in.put(PathMetricUnitIn{branchMetric:  bmuReverseOut.first.metric, 
                                          initPathMetric: initPathMetricZero()});
      backwardPathLast.enq(bmuReverseOut.first.backwardCtrl);
   endrule


   // We cannot put this directly in. 
   // Need a second FIFO.
   rule backwardsPMULast(bmuReverseOut.first.backwardCtrl.last);
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR PMU Last got last pmuBackwardReInit: %d @ %d", pmuBackwardReInit, clockCycles);
       end

      bmuReverseOut.deq;
      pmuBackwardReInit <= True;
      backwardPathLast.enq(bmuReverseOut.first.backwardCtrl);
   endrule

   
   //Hookup second reversal unit
   //We need to flush out extra data.  
   // need to treat last value as special.
   rule pmuUnReverse(!backwardPathLast.first.last);
     backwardPathLast.deq;
     let pmuOut <- pmuBackward.out.get;

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR PMU UnReverse got bitId %d Max %d (%h)", backwardPathLast.first.bitId, getPathMetricMaxIndex(pmuOut));
       end

     revBufferFinal.inputData.put(tuple2(backwardPathLast.first,pmuOut));     
   endrule

   rule pmuUnReverseLast(backwardPathLast.first.last);
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR PMU UnReverse last @ %d", clockCycles);
       end

     backwardPathLast.deq;
     revBufferFinal.inputData.put(tuple2(backwardPathLast.first,?));     
   endrule

   interface in = revBufferInitial.inputData;
   interface out = revBufferFinal.outputData;

endmodule
