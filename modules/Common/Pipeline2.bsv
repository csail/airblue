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

import Connectable::*;
import FIFO::*;
import GetPut::*;
import List::*;
import RWire::*;
import Vector::*;
//import EHRReg::*;
//import Debug::*;

`ifndef DEBUG_PIPELINE
typedef False DebugPipeline;
`else
typedef `DEBUG_PIPELINE DebugPipeline;
`endif

interface Pipeline2#(type a);
  interface Put#(a) in;
  interface Get#(a) out;
endinterface
  
// bypass pipestage with rwire, need to guarantee get can always fire
module mkPipeStage_RWire#(function ActionValue#(a) f(a mesg))
    (Pipeline2#(a)) provisos (Bits#(a,asz));

      RWire#(a) canGet <- mkRWire;

      interface Put in;
	 method Action put(a mesg);
            let a_res <- f(mesg);
	    canGet.wset(a_res);
	 endmethod
      endinterface
	  
      interface Get out;
	 method ActionValue#(a) get() if (isValid(canGet.wget));
            return fromMaybe(?, canGet.wget);
	 endmethod
      endinterface           
endmodule

// normal pipeStage with FIFO
module mkPipeStage_FIFO#(function ActionValue#(a) f(a mesg))
    (Pipeline2#(a)) provisos (Bits#(a,asz));

      FIFO#(a) outQ <- mkSizedFIFO(2);

      interface Put in;
	 method Action put(a mesg);
            let a_res <- f(mesg);
	    outQ.enq(a_res);
	 endmethod
      endinterface
	  
      interface out = fifoToGet(outQ);
endmodule


// normal pipeline
module [m] mkPipeline2_Norm#(Bit#(idx_sz) maxStage,
				 function m#(Pipeline2#(a)) mkP)
  (Pipeline2#(a)) provisos (Bits#(a, asz),
   IsModule#(m, mMod));

   // state elements
   Vector#(TExp#(idx_sz), Pipeline2#(a)) stageFUs = newVector;
   FIFO#(a) outQ <- mkSizedFIFO(2);
   stageFUs[0] <- mkP;
   for (Bit#(idx_sz) i = 1; i <= maxStage; i = i + 1)
     begin
	stageFUs[i] <- mkP;
	mkConnection(stageFUs[i-1].out, stageFUs[i].in);
     end
   mkConnection(stageFUs[maxStage].out, fifoToPut(outQ));
   
   // methods
   interface in = stageFUs[0].in;
   interface out = fifoToGet(outQ);   
endmodule // mkP

// circular pipeline, assume stageFU.out < stageFU.in or no conflict   
module [m] mkPipeline2_Circ#(Bit#(idx_sz) maxStage,
				 function m#(Pipeline2#(a)) mkP)
  (Pipeline2#(a)) provisos (Bits#(a, asz),IsModule#(m,mMod));
   
   // instantiate sharable functional unit
   //FIFO#(a) outQ <- mkSizedFIFO(2);
   RWire#(a) outWire <- mkRWire;
   Pipeline2#(a) stageFU <- mkP;
   EHRReg#(2,Maybe#(Bit#(idx_sz))) stage <- mkEHRReg(Invalid);
   RWire#(a) passData <- mkRWire;
   
   // constants
   Reg#(Maybe#(Bit#(idx_sz))) stage0 = (stage[0]);
   Reg#(Maybe#(Bit#(idx_sz))) stage1 = (stage[1]);

   rule getStageRes(isValid(stage0));
      let curStage = fromMaybe(?,stage0);
      let res <- stageFU.out.get;
      if (curStage == maxStage) // finish
	 begin
	    outWire.wset(res);
	    stage0 <= tagged Invalid;
	 end
      else
	 begin
	    passData.wset(res);
	    stage0 <= tagged Valid (curStage + 1);
	 end
//      $display("circ.getStageRes: stage: %d",curStage);
   endrule

   rule execNextStage(isValid(stage1) && isValid(passData.wget));
      let mesg = fromMaybe(?,passData.wget);
      stageFU.in.put(mesg);
//      $display("cir.execNextStage");
   endrule
   
//     rule printCheck(True);
//        $display("maxStage =  %d",maxStage);
//        $display("isValid(stage[0]) = %d",isValid(stage0));
//        $display("stage[0] = %d",fromMaybe(?,stage0));
//        $display("isValid(stage[1]) = %d",isValid(stage1));
//        $display("stage[1] = %d",fromMaybe(?,stage1));
//        $display("isValid(passData.wget) = %d",isValid(passData.wget));
//  //      $display("passData.wget = %d",fromMaybe(?,passData.wget));	
//     endrule
			    
   interface Put in;
      method Action put(a mesg) if (!isValid(stage1));
	 stageFU.in.put(mesg);
         stage1 <= tagged Valid 0;
      endmethod
   endinterface
   
   interface Get out;
     method ActionValue#(a) get() if(outWire.wget matches tagged Valid .data);
       return data;
     endmethod
   endinterface
endmodule // mkP


// time multiplex pipline
module [m] mkPipeline2_Time#(function m#(Pipeline2#(Vector#(psz,a))) mkP)
  (Pipeline2#(Vector#(sz,a)))
   provisos (Bits#(a, asz),
	     Div#(sz,psz,noStages), // div now change to return ceiling 
	     Log#(noStages,stage_idx),
	     Mul#(noStages,psz,total_sz),
	     Add#(sz,ext_sz,total_sz),
	     Bits#(Vector#(total_sz,a),xxA),
	     Bits#(Vector#(noStages,Vector#(psz,a)),xxA),
             IsModule#(m,mMod));

   // constants
   Integer maxStageInt = valueOf(noStages)-1;
   Bit#(stage_idx) maxStage = fromInteger(maxStageInt);
   Integer pSzInt = valueOf(psz);
   
   // state element
   Pipeline2#(Vector#(psz,a)) stageFU <- mkP;
   Reg#(Bit#(stage_idx)) putStage <- mkReg(0);
   Reg#(Bit#(stage_idx)) getStage <- mkReg(0);
   Vector#(noStages,FIFO#(Vector#(psz,a))) inBuffers = newVector;
   for (Integer i = 1; i <= maxStageInt; i = i + 1)
      inBuffers[i] <- mkLFIFO;
   Vector#(noStages,FIFO#(Vector#(psz,a))) outBuffers = newVector;
   outBuffers <- replicateM(mkLFIFO);
   
   rule startExec(putStage > 0);
   begin
      let mesg = inBuffers[putStage].first;
      inBuffers[putStage].deq;
      stageFU.in.put(mesg);
      putStage <= (putStage == maxStage) ? 0 : putStage + 1;
      if(DebugPipeline)
        begin
          $display("time.startExec: putStage: %d",putStage);
        end
   end
   endrule

   rule finishExec(True);
   begin
      let mesg <- stageFU.out.get;
      outBuffers[getStage].enq(mesg);
      getStage <= (getStage == maxStage) ? 0 : getStage + 1;
      if(DebugPipeline)
        begin
          $display("time.finishExec: getStage: %d",getStage);
        end
   end
   endrule

   interface Put in;
      method Action put(Vector#(sz,a) mesg) if (putStage == 0);
	 Vector#(ext_sz, a) extVec = newVector;
	 Vector#(total_sz, a) appendVec = append(mesg, extVec);
	 Vector#(noStages, Vector#(psz, a)) resVecs = unpack(pack(appendVec));
	 for (Integer i = 1; i <= maxStageInt; i = i + 1)
	    inBuffers[i].enq(resVecs[i]);
	 stageFU.in.put(resVecs[0]);
	 putStage <= (maxStageInt == 0) ? 0 : 1;
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(Vector#(sz,a)) get();
	 Vector#(noStages, Vector#(psz, a)) outVecs = newVector;
	 for (Integer i = 0; i <= maxStageInt; i = i + 1)
	   begin
	      outVecs[i] = outBuffers[i].first;
	      outBuffers[i].deq;
	   end	 
	 Vector#(total_sz, a) appendVec = unpack(pack(outVecs));
         return take(appendVec);
      endmethod
   endinterface     
endmodule // mkP

// time multiplex pipline, with constant control information passed through.
// This is module subsumes the above module, and should eventually replace 
// it.
// This is where the vertical pipeline folding occurs.
// This pipeline is synchronous, and may drop data.
module [m] mkPipeline2_TimeControl#(function m#(Pipeline2#(Tuple3#(ctrl_t,Bit#(stage_idx),Vector#(psz,a)))) mkP)
  (Pipeline2#(Tuple2#(ctrl_t,Vector#(sz,a))))
   provisos (Bits#(a, asz),
             Bits#(ctrl_t,ctrl_t_sz),
	     Div#(sz,psz,noStages), // div now change to return ceiling 
	     Log#(noStages,stage_idx),
	     Mul#(noStages,psz,total_sz),
	     Add#(sz,ext_sz,total_sz),
             Add#(noStagesMinusOne, 1, noStages),
	     Bits#(Vector#(total_sz,a),xxA),
	     Bits#(Vector#(noStages,Vector#(psz,a)),xxA),
             IsModule#(m,mMod));

   // constants
   Integer maxStageInt = valueOf(noStages)-1;
   Bit#(stage_idx) maxStage = fromInteger(maxStageInt);
   Integer pSzInt = valueOf(psz);

   // perhaps odd stuff here?
  
   FIFO#(Tuple2#(ctrl_t,Vector#(noStagesMinusOne,Vector#(psz,a)))) inBuffer <- mkLFIFO;   
  

   // state element
   Pipeline2#(Tuple3#(ctrl_t,Bit#(stage_idx),Vector#(psz,a))) stageFU <- mkP;
   Reg#(Bit#(stage_idx)) putStage <- mkReg(0);
   Reg#(Bit#(stage_idx)) getStage <- mkReg(0);

   Vector#(noStages,Reg#(Vector#(psz,a))) outRegs <-replicateM(mkReg(?));
   Reg#(ctrl_t) ctrlReg <- mkReg(?); 
   Vector#(noStages,FIFO#(Bit#(0))) tokenFIFOs <- replicateM(mkLFIFO);

   rule startExec(putStage > 0);
   begin
      match {.ctrl,.data} = inBuffer.first;
      stageFU.in.put(tuple3(ctrl,putStage,data[putStage-1]));
      putStage <= (putStage == maxStage) ? 0 : putStage + 1;
      if(putStage == maxStage) 
        begin
          if(DebugPipeline)
            begin
              $display("Calling in buffer deq");
            end

          inBuffer.deq;
        end

      if(DebugPipeline)
        begin
          $display("time.startExec: putStage: %d",putStage);
        end
   end
   endrule

   //Rules probably conflict...
   rule finishExec;
   begin
      let mesg <- stageFU.out.get;
      match {.ctrl,.num,.dataOut} = mesg; //I think num == maxStage... Maybe not?
      
      ctrlReg <= ctrl;
      tokenFIFOs[getStage].enq(0);
      outRegs[getStage] <= dataOut; 
      getStage <= (getStage == maxStage) ? 0 : getStage + 1;
      
      if(DebugPipeline)
        begin
          $display("time.finishExec: getStage: %d ctrl: %d num: %d",getStage, ctrl, num);
        end
   end
   endrule

   interface Put in;
      method Action put(Tuple2#(ctrl_t,Vector#(sz,a)) mesg) if (putStage == 0);
         match {.ctrl, .data} = mesg;
	 Vector#(ext_sz, a) extVec = newVector;
	 Vector#(total_sz, a) appendVec = append(data, extVec);
	 Vector#(noStages, Vector#(psz, a)) resVecs = unpack(pack(appendVec));
	 if(maxStageInt > 0)
	    inBuffer.enq(tuple2(ctrl,takeTail(resVecs)));

	 stageFU.in.put(tuple3(ctrl,0,resVecs[0]));
	 putStage <= (maxStageInt == 0) ? 0 : 1;
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(Tuple2#(ctrl_t,Vector#(sz,a))) get();
	 Vector#(total_sz, a) appendVec = unpack(pack(readVReg(outRegs)));
	 for (Integer i = 0; i <= maxStageInt; i = i + 1)
	   begin
	      tokenFIFOs[i].deq;
	   end	         
         return tuple2(ctrlReg,take(appendVec));      
      endmethod
   endinterface     
endmodule // mkP