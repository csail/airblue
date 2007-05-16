import FIFO::*;
import Monad::*;
import Traceback::*;
import Vector::*;
import VParams::*;
import VRegFile::*;
import Parameters::*;

//`define isDebug True // uncomment this line to display error

// useful integers definitions
Integer radix_sz = valueOf(RadixSz);
Integer no_states = valueOf(VTotalStates);
Integer fwd_steps = valueOf(FwdSteps);
Integer fwd_entry_sz = valueOf(FwdEntrySz);
Integer conv_in_sz = valueOf(ConvInSz);
Integer conv_out_sz = valueOf(ConvOutSz);
Integer vregs_out_sz = valueOf(VRegsOutSz);
Integer half_max_metric_sum = valueOf(TExp#(TLog#(TAdd#(VMaxMetricSum,1))));
Integer no_tbstage = valueOf(NoOfTBStage);

//////////////////////////////////////////////////////////
// begin of interface definitions
/////////////////////////////////////////////////////////

interface IViterbi;
  method Action putData (VInType dataIn);
  method ActionValue#(VOutType) getResult ();
endinterface


/////////////////////////////////////////////////////////
// Begin of library functions and modules
/////////////////////////////////////////////////////////

function VState getNextState(VState state, Bit#(ConvInSz) nextBits);
  let tmp = {nextBits, state};
  return tpl_1(split(tmp)); // drop LSBs
endfunction

function VState getPrevState(VState state, Bit#(ConvInSz) prevBits);
  let tmp = {state, prevBits};
  return tpl_2(split(tmp)); // drop MSBs
endfunction // ViterbiState

function Vector#(ConvOutSz, Bit#(KSz)) getConvVec();
      Vector#(ConvOutSz, Bit#(KSz)) outVec = newVector();
      outVec[0] = convEncoderG1;
      outVec[1] = convEncoderG2;
      return outVec;
endfunction // Vector

// get the output of the convolutional encoder. convention is
// {b, a} - meaning a is the low bit and b is the high bit
function Vector#(ConvOutSz, Bit#(1)) getConvEncOutput (VState state, 
						       Bit#(ConvInSz) inBits);

      Vector#(ConvOutSz, Bit#(KSz)) convVec = getConvVec();
      Bit#(KSz) temp = {inBits, state};
      Vector#(ConvOutSz, Bit#(1)) outVec = replicate(0);      
      for(Integer idx = 0; idx < valueOf(ConvOutSz); idx = idx + 1)
	for(Integer bitNum = 0; bitNum < valueOf (KSz); bitNum = bitNum + 1)
	  outVec[idx] = outVec[idx] + (temp[bitNum] & convVec[idx][bitNum]);
      return outVec;
endfunction

// this is used to calculate the index of data that i need to read
function Vector#(sz, Integer) getIdxLUT (Integer conv_in_sz, Integer stage);

      Integer v_sz = valueOf(sz);
      Integer shift_sz = conv_in_sz * stage;
      Integer mul_val = exp(2, shift_sz);
      Integer div_val = v_sz / mul_val; 
      Vector#(sz, Integer) outVec = newVector;
      for (Integer i = 0; i < v_sz; i = i + 1)
	   outVec[i] = ((i % div_val) * mul_val) + (i / div_val); // performing a circular right shift
      return outVec;

endfunction

// this actually perform the permutation
function Vector#(sz, val_t) vPermute (Integer conv_in_sz, Integer stage, Vector#(sz, val_t) inVec);
      
      return map(select(inVec), getIdxLUT(conv_in_sz, stage));

endfunction // Vector

// this actually perform the reverse permutation 
function Vector#(sz, val_t) reverseVPermute (Integer conv_in_sz, Integer stage, Vector#(sz, val_t) inVec);

      Integer v_sz = valueOf(sz);      
      Vector#(sz, val_t) outVec = newVector;
      Vector#(sz, Integer) lut = getIdxLUT(conv_in_sz, stage);
      for (Integer i = 0; i < v_sz; i = i + 1)
	outVec[lut[i]] = inVec[i];
      return outVec;

endfunction // Vector

// this function is passed as a parameter to mkVRegFile
function Vector#(out_sz, value_T) readSelect (Integer conv_in_sz,
					      Integer stage,
					      Bit#(sub_idx_sz) sidx, 
					      Vector#(row_sz, value_T) inVec)
  provisos (Log#(out_sz, out_idx_sz),
	    Log#(row_sz, row_idx_sz),
	    Add#(sub_idx_sz, out_idx_sz, row_idx_sz));
      Vector#(out_sz, value_T) outVec = newVector;
      Vector#(row_sz, value_T) newInVec = vPermute(conv_in_sz, stage, inVec);
      Nat shiftN = fromInteger(valueOf(out_idx_sz));
      for (Integer i = 0; i < valueOf(out_sz); i = i + 1)
	begin
	   Bit#(out_idx_sz) idx1 = fromInteger(i);
	   Bit#(row_idx_sz) idx2 = zeroExtend(idx1) + (zeroExtend(sidx) << shiftN);
	   outVec[idx1] = newInVec[idx2];
	end
      return outVec;
endfunction

// this function is passed as a parameter to mkVRegFile
function Vector#(row_sz, value_T) reverseReadSelect (Integer conv_in_sz,
						     Integer stage,
						     Bit#(sub_idx_sz) sidx, 
						     Vector#(out_sz, value_T) inVec)
  provisos (Log#(out_sz, out_idx_sz),
	    Log#(row_sz, row_idx_sz),
	    Add#(sub_idx_sz, out_idx_sz, row_idx_sz));
      Vector#(row_sz, value_T) outVec = newVector;
      Nat shiftN = fromInteger(valueOf(out_idx_sz));
      for (Integer i = 0; i < valueOf(out_sz); i = i + 1)
	begin
	   Bit#(out_idx_sz) idx1 = fromInteger(i);
	   Bit#(row_idx_sz) idx2 = zeroExtend(idx1) + (zeroExtend(sidx) << shiftN);
	   outVec[idx2] = inVec[idx1];
	end
      outVec = reverseVPermute(conv_in_sz, stage, outVec);      
      return outVec;
endfunction

// this function passed as a parameter to mkVRegFile
function Vector#(row_sz, value_T) writeSelect (Bit#(sub_idx_sz) sidx, 
					       Vector#(row_sz, value_T) inVec1,
					       Vector#(out_sz, value_T) inVec2)
  provisos (Log#(out_sz, out_idx_sz),
	    Log#(row_sz, row_idx_sz),
	    Add#(sub_idx_sz, out_idx_sz, row_idx_sz));
      Vector#(row_sz, value_T) outVec = inVec1;
      Nat shiftN = fromInteger(valueOf(out_idx_sz));
      for (Integer i = 0; i < valueOf(out_sz); i = i + 1)
	begin
	   Bit#(out_idx_sz) idx1 = fromInteger(i);
	   Bit#(row_idx_sz) idx2 = zeroExtend(idx1) + (zeroExtend(sidx) << shiftN);
	   outVec[idx2] = inVec2[idx1];
	end
      return outVec;
endfunction
				

(* synthesize *)
module mkMetricSums (VRegFile#(VRegsSubIdxSz,VRegsOutSz,VMetricSum));
   
   let vRegFile <- mkVRegFile(readSelect(conv_in_sz, fwd_steps),writeSelect, 0);
   return vRegFile;

endmodule // mkVRegFileFull

(* synthesize *)
module mkTrellis (VRegFile#(VRegsSubIdxSz,VRegsOutSz,VTrellisEntry));

   let vRegFile <- mkVRegFile(readSelect(conv_in_sz, fwd_steps),writeSelect, 0);
   return vRegFile;

endmodule // mkVRegFileFull

function VMetric getMetric(Bit#(1) in);
      return ((in == 0) ? 0 : maxBound);
endfunction // Metric
      

// generate the metric look up table
// table index = {nextState, prevStateSuffix}
(* noinline *)
function MetricLUT getMetricLUT();
      
      MetricLUT outVec = newVector;
      for (Integer next_state = 0; next_state < no_states; next_state = next_state + 1)
	begin
	   VState nextState = fromInteger(next_state);
	   Tuple2#(Bit#(ConvInSz), Bit#(TSub#(VStateSz, ConvInSz))) nsTup = split(nextState);
	   Bit#(ConvInSz) inBits = tpl_1(nsTup);
	   Bit#(TSub#(VStateSz, ConvInSz)) prevStatePrefix = tpl_2(nsTup);
	   for (Integer prev_state_suffix = 0; prev_state_suffix < radix_sz; prev_state_suffix = prev_state_suffix + 1)
	     begin
		Bit#(ConvInSz) prevStateSuffix = fromInteger(prev_state_suffix);
		VState prevState = {prevStatePrefix, prevStateSuffix};
		Vector#(ConvOutSz, Bit#(1)) convOut = getConvEncOutput(prevState, inBits);
		outVec[next_state*radix_sz + prev_state_suffix] = map(getMetric, convOut);
	     end
	end // for (Integer next_state = 0; next_state < no_states; next_state = next_state + 1)
      return outVec;

endfunction	     

function PrimEntry#(tEntry_T) chooseMin (PrimEntry#(tEntry_T) in1, 
					 PrimEntry#(tEntry_T) in2);
      
      return ((tpl_2(in1) - tpl_2(in2) < fromInteger(half_max_metric_sum)) ? in2 : in1); 

endfunction // Tuple3

// used for create a TB path
function VTrellisEntry getNextTrellisEntry (VState prevState,
					    VState nextState,
					    VTrellisEntry oldTEntry);

      Bit#(ConvInSz) inBit = tpl_1(split(nextState));
      return tpl_1(split({inBit, oldTEntry})); // shift out LSBs

endfunction // VTrellisEntry

// used for create a TB col, MSB = oldest column
function Bit#(VStateSuffixSz) getNextTB (VState prevState,
					 VState nextState,
					 Bit#(VStateSuffixSz) oldTEntry);

      Bit#(ConvInSz) inBit = tpl_2(split(prevState));
      return tpl_1(split({inBit, oldTEntry})); // shift out LSBs

endfunction // VTrellisEntry

function RadixEntry#(tEntry_T) radixCompute(RadixEntry#(tEntry_T) inVec,
					    Vector#(ConvOutSz, VMetric) inMetrics,
					    function tEntry_T getNextTEntry(VState prevState,
									    VState nextState,
									    tEntry_T oldTEntry));

      function VMetricSum calcVMetricSum (VMetricSum inSum,
					  Vector#(ConvOutSz, Bit#(1)) expBits,
					  Vector#(ConvOutSz, VMetric) recMetrics);
           Vector#(ConvOutSz, VMetricSum) addMetrics = newVector;
           for (Integer i = 0; i < conv_out_sz; i = i + 1)
	     addMetrics[i] = zeroExtend(getMetric(expBits[i]) ^ recMetrics[i]); // |expMetric[i] - recMetrics[i]|
           return inSum + fold(\+ , addMetrics);
      endfunction
      
      RadixEntry#(tEntry_T) outVec = newVector;
//      MetricLUT metricLUT = getMetricLUT;
      Bit#(TSub#(VStateSz, ConvInSz)) prevStatePrefix = tpl_1(split(tpl_1(inVec[0]))); // all input states must have the same prefix
      RadixEntry#(tEntry_T) sumVec = newVector; // for calculating next result      
      for (Integer in_bits = 0; in_bits < radix_sz; in_bits = in_bits + 1)
	begin
	   Bit#(ConvInSz) inBits = fromInteger(in_bits);
	   VState nextState = {inBits, prevStatePrefix};
	   for (Integer prev_state_suffix = 0; prev_state_suffix < radix_sz; prev_state_suffix = prev_state_suffix + 1)
	     begin
//		Bit#(KSz) lutIdx = (zeroExtend(nextState) << fromInteger(conv_in_sz)) + fromInteger(prev_state_suffix);
		sumVec[prev_state_suffix] = tuple3(tpl_1(inVec[prev_state_suffix]),  // same
						   calcVMetricSum(tpl_2(inVec[prev_state_suffix]),
								  getConvEncOutput(tpl_1(inVec[prev_state_suffix]), inBits),
//								  metricLUT[lutIdx],
								  inMetrics), // add 
						   tpl_3(inVec[prev_state_suffix])); // same
	     end
	   let minRadix = fold(chooseMin, sumVec);
	   let nextSum = tpl_2(minRadix);
	   let nextT = getNextTEntry(tpl_1(minRadix), nextState, tpl_3(minRadix));
	   outVec[in_bits] = tuple3(nextState, nextSum, nextT);
	end // for (Integer in_bits = 0; in_bits < radix_sz; in_bits = in_bits + 1)
      return outVec;

endfunction // unmatched end(function|task|module|primitive)
      
function FwdEntry#(tEntry_T) fwdCompute(FwdEntry#(tEntry_T) inVec,
					VInType inMetricsV,
					function tEntry_T getNextTEntry(VState prevState,
									VState nextState,
									tEntry_T oldTEntry));
      
      FwdEntry#(tEntry_T) outVec = inVec;
      Integer no_radix = fwd_entry_sz / radix_sz; 
      for (Integer stage = 0; stage < fwd_steps; stage = stage + 1)
	begin
	   RadixEntry#(tEntry_T) radixVec = newVector;
	   if (stage != 0)
	     outVec = readSelect(conv_in_sz, stage, 0, outVec); // permute if not the first step
	   for (Integer radix_idx = 0; radix_idx < no_radix; radix_idx = radix_idx + 1)
	     begin
		for (Integer k = 0; k < radix_sz; k = k + 1)
		  radixVec[k] = outVec[radix_idx*radix_sz+k];
	        radixVec = radixCompute(radixVec, inMetricsV[stage], getNextTEntry);
		for (Integer k = 0; k < radix_sz; k = k + 1)
		  outVec[radix_idx*radix_sz+k] = radixVec[k];
	     end // for (Integer j = 0; j < noOfRadix; j = j + 1)
	   if (stage != 0)
	     outVec = reverseReadSelect(conv_in_sz, stage, 0, outVec); // reverse the permutation if not the first step
	end // for (Integer i = 0; i < fwd_steps; i = i + 1)
      return outVec;
      
endfunction // ForwardEntry

// output the state with the minimum value and the new outentry
function Tuple3#(VState, tEntry_T, VRegsOutEntry#(tEntry_T)) vRegsOutCompute(VRegsOutEntry#(tEntry_T) inVec,
									     VInType inMetricsV,
									     function tEntry_T getNextTEntry(VState prevState,
													     VState nextState,
													     tEntry_T oldTEntry));
      
      VRegsOutEntry#(tEntry_T) outVec = newVector;
      Integer no_fwd_unit = vregs_out_sz / fwd_entry_sz;
      FwdEntry#(tEntry_T) fwdVec = newVector;
      for (Integer fwd_idx = 0; fwd_idx < no_fwd_unit; fwd_idx = fwd_idx + 1)
	begin
	   for (Integer k = 0; k < fwd_entry_sz; k = k + 1)
	     fwdVec[k] = inVec[fwd_idx * fwd_entry_sz + k];
	   fwdVec = fwdCompute(fwdVec, inMetricsV, getNextTEntry);
	   for (Integer k = 0; k < fwd_entry_sz; k = k + 1)
	     outVec[fwd_idx * fwd_entry_sz + k] = fwdVec[k];
	end // for (Integer j = 0; j < noOfRadix; j = j + 1)
      let minPrimEntry = fold(chooseMin, outVec);
      VState minState = tpl_1(minPrimEntry);
      tEntry_T minTEntry = tpl_3(minPrimEntry);
      return tuple3(minState, minTEntry, outVec);
      
endfunction // ForwardEntry

(* noinline *)
function Tuple3#(VState, VTrellisEntry, VRegsOutEntry#(VTrellisEntry)) vRegsOutComputeTBPath(VRegsOutEntry#(VTrellisEntry) inVec,
											     VInType inMetricsV);
      
      return vRegsOutCompute(inVec, inMetricsV, getNextTrellisEntry);
      
endfunction

(* noinline *)
function Tuple3#(VState, VTBEntry, VRegsOutEntry#(VTBEntry)) vRegsOutComputeTB(VRegsOutEntry#(VTBEntry) inVec,
									       VInType inMetricsV);
      
      return vRegsOutCompute(inVec, inMetricsV, getNextTB);
      
endfunction

function Vector#(VRegsOutSz, VState) getNextStates(Bit#(VRegsSubIdxSz) stage);

      Vector#(VRegsOutSz, VState) outVec = newVector;
      VState subIdx = zeroExtend(stage) << fromInteger(valueOf(VRegsOutIdxSz));
      for (Integer i = 0; i < valueOf(VRegsOutSz); i = i + 1)
	outVec[i] = subIdx + fromInteger(i);
      return outVec;
      
endfunction // Vector
      

      
/////////////////////////////////////////////////////////
// Begin of Viterbi Module 
/////////////////////////////////////////////////////////


(*synthesize*)
module mkIViterbiTBPath (IViterbi);

   // states
   FIFO#(VInType) inQ <- mkLFIFO;
   FIFO#(VOutType) outQ <- mkSizedFIFO(2);
   VRegFile#(VRegsSubIdxSz,VRegsOutSz,VMetricSum) metricSums <- mkMetricSums;
   VRegFile#(VRegsSubIdxSz,VRegsOutSz,VTrellisEntry) trellis <- mkTrellis;
   Reg#(Bit#(VRegsSubIdxSz)) stage <- mkReg(0);
   Reg#(Bit#(1)) colIdx <- mkReg(0);
   Reg#(VState)  curMinState <- mkReg(0);
   Reg#(VTrellisEntry) curMinPath <- mkRegU;
   Reg#(TBStageIdx)   tbStage <- mkReg(0); // keep track of whether we can output TB result yet
   


   rule processInput(True);
   begin
      let nextMSums = metricSums.sub(colIdx, stage);
      let nextTrellis = trellis.sub(colIdx, stage);
      let nextStates = getNextStates(stage);
      let vRegsOutEntry = zip3(nextStates, nextMSums, nextTrellis);
      let vRegsOutNew = vRegsOutComputeTBPath(vRegsOutEntry, inQ.first);
      let minState = tpl_1(vRegsOutNew);
      let minPath = tpl_2(vRegsOutNew);
      let newMinState = (stage == 0 || minState < curMinState) ? minState : curMinState;
      let newMinPath = (stage == 0 || minState < curMinState) ? minPath : curMinPath;
      let newMSums = map(tpl_2, tpl_3(vRegsOutNew));
      let newTrellis = map(tpl_3, tpl_3(vRegsOutNew));
      Bit#(VStateSuffixSz) out = tpl_2(split(newMinPath));
      VOutType vOut = unpack(out);
      curMinState <= newMinState; // new min
      curMinPath <= newMinPath;
      stage <= stage + 1;
      metricSums.upd(colIdx+1, stage, newMSums);
      trellis.upd(colIdx+1, stage, newTrellis);
      `ifdef isDebug
         $display ("viterbi return: colIdx=%d stage=%d newMinState=%d, newMinPath=%h", colIdx, stage, newMinState, newMinPath);
         $write ("viterbi return: newMSums=");
         for (Integer i = 0; i < no_states; i = i + 1)
	   begin
	      $write ("%d: %d ", tpl_1(tpl_3(vRegsOutNew)[i]), newMSums[i]);
	   end
         $display ("");
         $write ("viterbi return: newTrellis=");
	 for (Integer i = 0; i < no_states; i = i + 1)
	   begin
	      $write ("%d: %h ", tpl_1(tpl_3(vRegsOutNew)[i]), newTrellis[i]);
	   end
	 $display ("");
      `endif
      if (stage == maxBound) // last stage, output trace back
	begin
	   inQ.deq;
	   if (tbStage == fromInteger(no_tbstage-1))
	     outQ.enq(vOut);
	   else
	     tbStage <= tbStage + 1;
	   colIdx <= colIdx + 1;
	end
   end
   endrule
   
   method Action putData (VInType dataIn);
      inQ.enq(dataIn);
   endmethod

   method ActionValue#(VOutType) getResult ();
      outQ.deq;
      return outQ.first;
   endmethod
   
endmodule

(*synthesize*)
module mkIViterbiTB (IViterbi);

   // states
   FIFO#(VInType) inQ <- mkLFIFO;
   FIFO#(VOutType) outQ <- mkSizedFIFO(2);
   VRegFile#(VRegsSubIdxSz,VRegsOutSz,VMetricSum) metricSums <- mkMetricSums;
   Reg#(Vector#(VTotalStates, Bit#(1))) tbcol <- mkRegU; // save tb col
   Reg#(Bit#(VRegsSubIdxSz)) stage <- mkReg(0);
   Reg#(Bit#(1)) colIdx <- mkReg(0);
   Reg#(VState)  curMinState <- mkReg(0);
   Reg#(TBStageIdx)   tbStage <- mkReg(0); // keep track of whether we can output TB result yet
   Traceback  tbu <- mkTraceback;

   rule performACS(True);
   begin
      let nextMSums = metricSums.sub(colIdx, stage);
      let nextTBEntry = newVector;
      let nextStates = getNextStates(stage);
      let vRegsOutEntry = zip3(nextStates, nextMSums, nextTBEntry);
      let vRegsOutNew = vRegsOutComputeTB(vRegsOutEntry, inQ.first);
      let minState = tpl_1(vRegsOutNew);
      let newMinState = (stage == 0 || minState < curMinState) ? minState : curMinState;
      let newMSums = map(tpl_2, tpl_3(vRegsOutNew));
      let newTBEntry = map(tpl_3, tpl_3(vRegsOutNew));
      let newTBCol = writeSelect(stage, tbcol, newTBEntry);
      curMinState <= newMinState; // new min
      stage <= stage + 1;
      metricSums.upd(colIdx+1, stage, newMSums);
      tbcol <= newTBCol; 
      `ifdef isDebug
         $display ("viterbi return: colIdx=%d stage=%d newMinState=%d", colIdx, stage, newMinState);
         $write ("viterbi return: newMSums=");
         for (Integer i = 0; i < no_states; i = i + 1)
	   begin
	      $write ("%d: %d ", tpl_1(tpl_3(vRegsOutNew)[i]), newMSums[i]);
	   end
         $display ("");
         $write ("viterbi return: newTBEntry=");
	 for (Integer i = 0; i < no_states; i = i + 1)
	   begin
	      $write ("%d: %h ", tpl_1(tpl_3(vRegsOutNew)[i]), newTBEntry[i]);
	   end
	 $display ("");
      `endif
      if (stage == maxBound) // last stage, output trace back
	begin
	   inQ.deq;
	   colIdx <= colIdx + 1;
	   tbu.updateMemory(vPermute(conv_in_sz, fwd_steps, newTBCol), newMinState); // put to traceback
	end
   end
   endrule

   rule performTB(True);
   begin
      let result <- tbu.getDecodedOutput; //get result from tb
      outQ.enq(unpack(pack(result)));
   end
   endrule
   
   method Action putData (VInType dataIn);
      inQ.enq(dataIn);
   endmethod

   method ActionValue#(VOutType) getResult ();
      outQ.deq;
      return outQ.first;
   endmethod
   
endmodule
