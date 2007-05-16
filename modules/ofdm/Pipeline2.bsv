import Connectable::*;
import FIFO::*;
import GetPut::*;
import List::*;
import RWire::*;
import Vector::*;
import EHRReg::*;

interface Pipeline2#(type a);
  interface Put#(a) in;
  interface Get#(a) out;
endinterface
  
// bypass pipestage with rwire, need to guarantee get can always fire
module mkPipeStage_RWire#(function a f(a mesg))
    (Pipeline2#(a)) provisos (Bits#(a,asz));

      RWire#(a) canGet <- mkRWire;

      interface Put in;
	 method Action put(a mesg);
	    canGet.wset(f(mesg));
	 endmethod
      endinterface
	  
      interface Get out;
	 method ActionValue#(a) get() if (isValid(canGet.wget));
            return fromMaybe(?, canGet.wget);
	 endmethod
      endinterface           
endmodule

// normal pipeStage with FIFO
module mkPipeStage_FIFO#(function a f(a mesg))
    (Pipeline2#(a)) provisos (Bits#(a,asz));

      FIFO#(a) outQ <- mkSizedFIFO(2);

      interface Put in;
	 method Action put(a mesg);
	    outQ.enq(f(mesg));
	 endmethod
      endinterface
	  
      interface out = fifoToGet(outQ);
endmodule


// normal pipeline
module [Module] mkPipeline2_Norm#(Bit#(idx_sz) maxStage,
				 function Module#(Pipeline2#(a)) mkP)
  (Pipeline2#(a)) provisos (Bits#(a, asz));

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
module [Module] mkPipeline2_Circ#(Bit#(idx_sz) maxStage,
				 function Module#(Pipeline2#(a)) mkP)
  (Pipeline2#(a)) provisos (Bits#(a, asz));
   
   // instantiate sharable functional unit
   FIFO#(a) outQ <- mkSizedFIFO(2);
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
	    outQ.enq(res);
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
   
   interface out = fifoToGet(outQ);
endmodule // mkP

// time multiplex pipline
module [Module] mkPipeline2_Time#(function Module#(Pipeline2#(Vector#(psz,a))) mkP)
  (Pipeline2#(Vector#(sz,a)))
   provisos (Bits#(a, asz),
	     Div#(sz,psz,noStages), // div now change to return ceiling 
	     Log#(noStages,stage_idx),
	     Mul#(noStages,psz,total_sz),
	     Add#(sz,ext_sz,total_sz),
	     Bits#(Vector#(total_sz,a),xxA),
	     Bits#(Vector#(noStages,Vector#(psz,a)),xxA));

   // constants
   Integer maxStageInt = valueOf(noStages)-1;
   Bit#(stage_idx) maxStage = fromInteger(maxStageInt);
   Integer pSzInt = valueOf(psz);
   
   // state element
   Pipeline2#(Vector#(psz,a)) stageFU <- mkP;
   Reg#(Bit#(stage_idx)) putStage <- mkReg(0);
   Reg#(Bit#(stage_idx)) getStage <- mkReg(0);
   Vector#(noStages,FIFO#(Vector#(psz,a))) inBuffers = newVector;
   inBuffers <- replicateM(mkLFIFO);
   Vector#(noStages,FIFO#(Vector#(psz,a))) outBuffers = newVector;
   outBuffers <- replicateM(mkLFIFO);
   
   rule startExec(putStage > 0);
   begin
      let mesg = inBuffers[putStage].first;
      inBuffers[putStage].deq;
      stageFU.in.put(mesg);
      putStage <= (putStage == maxStage) ? 0 : putStage + 1;
//      $display("time.startExec: putStage: %d",putStage);
   end
   endrule

   rule finishExec(True);
   begin
      let mesg <- stageFU.out.get;
      outBuffers[getStage].enq(mesg);
      getStage <= (getStage == maxStage) ? 0 : getStage + 1;
//      $display("time.finishExec: getStage: %d",getStage);
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
				     
				     
				     
				  				     
				     
				     
				     
				     
				     
				     
				     
				     
				     
