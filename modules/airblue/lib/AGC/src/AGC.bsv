// The purpose of this is to detect energy edges and adjust them to an appropriate energy level 


typedef 16 AGCValue;
typedef TMul#(100/20*(80*   AGCTimeout; //  What if we get stuck.  Probably want to get out. 

Integer PreamblePeriod = 

Bit#(AGCValue) defaultAGC = ?;  // figure this out at somepoint



interface AGC;
  method Action inputSample(SynchronizerMesg#(2,14) sample);
  method ActionValue#(AGCValue) getAGCUpdate;
endinterface

typedef enum {
  Idle,
  Adjust,
  Packet
} AGCState deriving (Bits,Eq);


module mkAGC#() (AGC);

   NumTypeParam#(80) fifo_sz = 0;
   FIFOCountIfc#(Bit#(7),) delay80Data <- mkSizedBRAMFIFOCount();
   FIFOF#(Bit#(32)) samplesDelay80 <- mkSizedFIFO(fifo_sz);


endmodule