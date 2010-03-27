import Connectable::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import FShow::*;
import Probe::*;

//`include "../../../WiFiFPGA/Macros.bsv"

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/reversal_buffer.bsh"

/////////////////////////////////////////////////////////
// Begin of BCJR Module 

(*synthesize*)
module mkIBCJR (IViterbi);
   
   // BCJR Frontend
   BranchMetricUnit bmu <- mkBranchMetricUnit; 
   Reg#(BCJRBitId) bitId <- mkReg(0);

   // Forward Path Blocks
   PathMetricUnit   pmuForward <- mkPathMetricUnit("BCJR PMU Forward",getPMUOutBCJRForward,getBranchMetricForward);
   FIFOF#(VBranchMetricUnitOut) bmuForwardOut <- mkSizedFIFOF(`REVERSAL_BUFFER_SIZE*4);
   FIFOF#(VPathMetricUnitOut)   pmuForwardOut <- mkSizedFIFOF(`REVERSAL_BUFFER_SIZE*4);
   FIFOF#(Vector#(VTotalStates,VPathMetric))   forwardPathMetric <- mkSizedFIFOF(4);

   // Reverse Path Blocks
   ReversalBuffer#(Tuple2#(BCJRBitId,VBranchMetricUnitOut),BCJRBackwardCtrl,`REVERSAL_BUFFER_SIZE) revBufferInitial <- mkReversalBuffer("BCJR revInitial");
   ReversalBuffer#(VPathMetricUnitOut,BCJRBackwardCtrl,`REVERSAL_BUFFER_SIZE) revBufferFinal  <- mkReversalBuffer("BCJR revFinal");
   PathMetricUnit pmuBackwardEstimator <- mkPathMetricUnit("BCJR PMU Backwards Estimator",getPMUOutBCJRBackward,getBranchMetricBackward);
   PathMetricUnit pmuBackward         <- mkPathMetricUnit("BCJR PMU Backwards",getPMUOutBCJRBackward,getBranchMetricBackward);
   Reg#(Bit#(`REVERSAL_BUFFER_SIZE)) revResetCounter <- mkReg(0);
   Reg#(Bit#(`REVERSAL_BUFFER_SIZE)) forwardInitCounter <- mkReg(0);
   Reg#(Bool) firstBlock <- mkReg(True);
   FIFOF#(BackwardPathCtrl) bmuReverseOut <- mkSizedFIFOF(4*valueof(`REVERSAL_BUFFER_SIZE));
   Reg#(Bool) bmuPushLast <- mkReg(False);   
   FIFOF#(BCJRBackwardCtrl) backwardPathLast <- mkSizedFIFOF(4*valueof(`REVERSAL_BUFFER_SIZE)); // Must cover latency of decision unit   
   
   Reg#(Bool) pmuBackwardReInit <- mkReg(True);
   Reg#(Bool) decisionReInit <- mkReg(True);
   FIFOF#(PMUBackwardIntialState) backwardsInit <- mkSizedFIFOF(8);

   Reg#(Bit#(32)) clockCycles <- mkReg(0);

   rule tickClock;
     clockCycles <= clockCycles + 1;
   endrule   


   // Some diagnostic
   if(`DEBUG_BCJR == 1)
     begin
       rule diagnostic;
         $display("BCJR Diganostic bmuForwardOut: ", fshow(bmuForwardOut));
         $display("BCJR Diganostic pmuForwardOut: ", fshow(pmuForwardOut));
         $display("BCJR Diganostic forwardPathMetric: ", fshow(forwardPathMetric));
         $display("BCJR Diganostic bmuReverseOut: ", fshow(bmuReverseOut));
         $display("BCJR Diganostic backwardPathLast: ", fshow(backwardPathLast));
         $display("BCJR Diganostic backwardsInit: ", fshow(backwardsInit));
       endrule
     end



   //Decision Blocks
   DecisionUnit decisionUnit <- mkDecisionUnit;

   // may need to push through one last last, as we no long push zeros...

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
     revBufferInitial.inputData.put(tuple2(BCJRBackwardCtrl{last:False, bitId: bitId},tuple2(bitId,(tuple2(pushReset,data)))));
   endrule


   rule feedPMUForward;
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: pushing bmu data to forward unit");
       end
     bmuForwardOut.deq;
     pmuForward.in.put(PathMetricUnitIn{branchMetric: bmuForwardOut.first, initPathMetric: initPathMetricZero()});
   endrule


   // Never send initialization for first block
   Reg#(Bool) firstBlockForward <- mkReg(True);
   // Send the pmuForward Estimates to the backward path
   rule feedEstimates;
     let pmuForwardResult <- pmuForward.out.get();
     pmuForwardOut.enq(pmuForwardResult);

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR Forward Path counter: %d", forwardInitCounter);
       end

     if(tpl_1(pmuForwardResult)) 
       begin
         if(`DEBUG_BCJR == 1)
           begin
             $display("BCJR Forward Path sends initialization to backward path (final bit)");
           end

         forwardPathMetric.enq(tpl_1(unzip(tpl_2(pmuForwardResult))));
         forwardInitCounter <= 0;
         firstBlockForward <= True;
       end
     else if(forwardInitCounter + 1 == `REVERSAL_BUFFER_SIZE)
       begin
         if(`DEBUG_BCJR == 1)
           begin
             $display("BCJR Forward Path sends initialization to backward path (block)");
           end

         forwardPathMetric.enq(tpl_1(unzip(tpl_2(pmuForwardResult))));
         firstBlockForward <= False;
         forwardInitCounter <= 0;
       end
     else
       begin
         forwardInitCounter <= forwardInitCounter + 1;
       end

     if(tpl_1(pmuForwardResult) && (`DEBUG_BCJR == 1)) 
       begin 
         $display("BCJR Forward Path reset");
       end
   endrule

   rule bmuReversePushLast (bmuPushLast);
     bitId <= 0;
     revResetCounter <= 0;
     bmuPushLast <= False;
     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR initial push last, total bits: %d @ %d", bitId, clockCycles);
       end

     revBufferInitial.inputData.put(tuple2(BCJRBackwardCtrl{last:True, bitId: ~0},?));
   endrule


   Reg#(Bit#(32)) pmuESTEnq <- mkReg(0);
   //Rev Buffer data 
   let revBufferInitialResult = peekGet(revBufferInitial.outputData);
   match {.revBufferCtrl, .revBufferPayload} = revBufferInitialResult; 
   match {.revBufferId, .revBufferInitialPayload } = revBufferPayload;
   let revBufferInitialLast = revBufferCtrl.last; 
   let revBufferInitialId = revBufferCtrl.bitId; 

   rule revBufferInitialData(`DEBUG_BCJR == 1);
     $display("BCJR Diagnostic: RevBufferInitial: ", fshow(peekGet(revBufferInitial.outputData)));
   endrule

   // This reg holds the initial values of the PMU for a cycle. 

   rule backwardsPMUEstimator(!revBufferInitialLast);
     let revBufferResult <- revBufferInitial.outputData.get;
     match {.need_rst, .bmuOut} = revBufferInitialPayload;

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR Backwards Estimator fires: %d", clockCycles);
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
         // XXX change this one....
         pmuBackwardEstimator.in.put(PathMetricUnitIn{branchMetric: revBufferInitialPayload, initPathMetric: forwardPathMetric.first()});
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
         //We get one every block
         if(`DEBUG_BCJR == 1)
           begin
             $display("BCJR Backwards Estimator: Deq Forward Path metric");
           end

         forwardPathMetric.deq();
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
      // here we do not expect to actually use the reset value
      pmuBackward.in.put(PathMetricUnitIn{branchMetric:  bmuReverseOut.first.metric, 
                                          initPathMetric: initPathMetricZero()});
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
    

   Reg#(Bit#(32)) packetBits <- mkReg(0); 
   

   // Due to the path metric off by one issue, this stuff now has to be slightly modified. 
   rule feedDecisionUnit(!tpl_1(peekGet(revBufferFinal.outputData)).last && !decisionReInit);
     let backwardProbs <- revBufferFinal.outputData.get;
     let forwardProbs = pmuForwardOut.first;
     pmuForwardOut.deq;

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: Decision Unit is being fed bitId %d",tpl_1(peekGet(revBufferFinal.outputData)).bitId);
       end

     decisionUnit.in.put(tuple2(tpl_2(backwardProbs),forwardProbs));
   endrule

   rule feedDecisionUnitEatFirst(!tpl_1(peekGet(revBufferFinal.outputData)).last && decisionReInit);
     let backwardProbs <- revBufferFinal.outputData.get;

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: Decision Unit Clear Backwards Last");
       end

     decisionReInit <= False;
   endrule

   rule feedDecisionUnitEatLast(tpl_1(peekGet(revBufferFinal.outputData)).last && decisionReInit);
     let backwardProbs <- revBufferFinal.outputData.get;

     if(`DEBUG_BCJR == 1)
       begin
         $display("BCJR: Decision Unit Clear Extra Backward bit @ %d", clockCycles);
       end
   endrule

   rule feedDecisionUnitReplaceFirst(tpl_1(peekGet(revBufferFinal.outputData)).last && !decisionReInit);
     //let forwardProbs <- pmuForward.out.get;
     decisionReInit <= True;
     let forwardProbs = pmuForwardOut.first;
     pmuForwardOut.deq;
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


// for now, we handle only one forward step.
// This wrapper is for the deserializing of the BCJR
//module mkBCJR#(function Bool decodeBoundary(ctrl_t ctrl)) (Viterbi#(ctrl_t,n2,n))
module mkConvDecoder#(function Bool decodeBoundary(ctrl_t ctrl)) (Viterbi#(ctrl_t,n2,n))
   provisos(Log#(n2,ln2),
	    Log#(n,ln),
            FShow#(ctrl_t),
	    Bits#(ctrl_t, ctrl_sz));
   
   // constants
   // n must be multiple of fwd_steps * conv_in_sz
   Bit#(ln)  check_n   = fromInteger(valueOf(n)-(fwd_steps * conv_in_sz));
   // n must be multiple of fwd_steps * conv_out_sz
   Bit#(ln2) check_n2  = fromInteger(valueOf(n2)-(fwd_steps * conv_out_sz));

   // These may lead to death.... figure them out. Probably have to be bigger due to depth of pipeline
   Integer   bmu_latency = 3; // 2 fifos + 1 cycle
   Integer   pmu_latency = 1; // 1 cycle
   Integer   tbu_latency = no_tb_stages + 1; // no. tb stages + 1 fifo cycle
   Integer   ctrl_q_sz = ((bmu_latency+pmu_latency+tbu_latency)/valueOf(n)) + 1; 
   
   IViterbi bcjr <- mkIBCJR;  
   FIFOF#(DecoderMesg#(ctrl_t,n2,ViterbiMetric)) in_q <- mkLFIFOF;
   Reg#(Bit#(ln2)) in_data_count <- mkReg(0);
   Reg#(Bit#(32)) in_total_data_count <- mkReg(0);
   Reg#(Vector#(n,ViterbiOutput)) out_data <- mkReg(newVector);
   Reg#(Bit#(ln)) out_data_count <- mkReg(0);
   Reg#(Bit#(32)) out_total_data_count <- mkReg(0);
   FIFOF#(DecoderMesg#(ctrl_t,n,ViterbiOutput)) out_q <- mkSizedFIFOF(2);
   FIFOF#(ctrl_t) ctrl_q <- mkSizedFIFOF(4*`REVERSAL_BUFFER_SIZE);

   rule dumpBCJRWrapperState(`DEBUG_BCJR==1);
     $display("BCJR Wrapper Diagnostic inQ: ", fshow(in_q));     
     $display("BCJR Wrapper Diagnostic outQ: ", fshow(out_q));     
     $display("BCJR Wrapper Diagnostic ctrlQ: ", fshow(ctrl_q));
     $display("BCJR Wrapper Diagnostic total in: %d  total out: %d ", in_total_data_count, out_total_data_count);     
   endrule


   rule pushDataToBCJR ;
      DecoderMesg#(ctrl_t,n2,ViterbiMetric) in_mesg = in_q.first;
      ctrl_t in_ctrl = in_mesg.control;
      Vector#(n2,ViterbiMetric) in_data = in_mesg.data;
      Vector#(1,Vector#(ConvOutSz, VMetric)) v_data = newVector;
      for (Integer i = 0; i < fwd_steps; i = i + 1)
	 begin
	    for (Integer j = 0; j < conv_out_sz; j = j + 1)
	       begin
		  let offset = i * conv_out_sz + j;
 		  v_data[i][j] = in_data[in_data_count + fromInteger(offset)];
	       end
	 end


      // when does it end?
      if (in_data_count == check_n2) // means we have finished processing input
         begin

            if(`DEBUG_BCJR == 1)
              begin
                $display("BCJR top level deqs value");
              end 

            in_q.deq;
            in_data_count <= 0;
            ctrl_q.enq(in_ctrl);
            if (decodeBoundary(in_ctrl))
              begin
                if(`DEBUG_BCJR == 1)
                  begin
                    $display("BCJR Pushing decode boundary");
                  end

                bcjr.putData(tuple2(True,v_data)); 
              end
            else
               begin
                bcjr.putData(tuple2(False,v_data)); 
              end
         end
      else
        begin
          in_data_count <= in_data_count + fromInteger(fwd_steps * conv_out_sz);
          in_total_data_count <= in_total_data_count + fromInteger(fwd_steps * conv_out_sz);
          bcjr.putData(tuple2(False,v_data)); 
        end


      if(`DEBUG_BCJR == 1)
        begin
          $display("pushDataToViterbi");
        end
   endrule
   

   rule pullDataFromBCJR (True);
      VOutType v_data <- bcjr.getResult();
      Vector#(n,ViterbiOutput) new_out_data = out_data;
      for (Integer i = 0 ; i < fwd_steps; i = i + 1)
	 begin
            for (Integer j = 0; j < conv_in_sz; j = j + 1)
               begin
                  let offset = i * conv_in_sz + j;
	          new_out_data[out_data_count+fromInteger(offset)] = v_data[i][j]; 
               end
	 end
      out_data <= new_out_data;
      if (out_data_count == check_n) // means we have finished processing output
         begin
           if(`DEBUG_BCJR == 1)
             begin      
	       $display("BCJR out data: %h", new_out_data);
             end
           out_q.enq(Mesg{control:ctrl_q.first, data:new_out_data});
           out_data_count <= 0;
           ctrl_q.deq;
         end
      else
         begin
            out_data_count <= out_data_count + fromInteger(fwd_steps * conv_in_sz);
            out_total_data_count <= out_total_data_count + fromInteger(fwd_steps * conv_in_sz);
         end

      if(`DEBUG_BCJR == 1)
        begin      
          $display("pullDataFromViterbi");
        end
   endrule

   interface in  = fifoToPut(fifofToFifo(in_q));
   interface out = fifoToGet(fifofToFifo(out_q)); 
  
endmodule

