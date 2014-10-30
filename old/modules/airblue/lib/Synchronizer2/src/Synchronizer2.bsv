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

import CBus::*;
import Complex::*;
import FIFO::*;
import FIFOF::*;
import FixedPoint::*;
import GetPut::*;
import RWire::*;
import Vector::*;


`include "asim/provides/airblue_parameters.bsh"
import AirblueCommon::*;
`include "asim/provides/airblue_shift_regs.bsh"
import AirblueTypes::*;
`include "asim/provides/register_library.bsh"
`include "asim/provides/c_bus_utils.bsh"


//
// Sample -> 32-sample auto CorrType -> detection -> detection + freq_offset
// -> 

typedef struct {
  Bool detect;
  Correlation autoCorrelation;
  Sample data;
} FreqEstimatorData deriving (Bits);

typedef struct {
   Sample sample;
   Bool detect;
   LongCorrelation corr;
} PacketDetect deriving (Bits);


typedef struct {
  Sample data;
  Bool detect;
} FineTimeData deriving (Bits);

typedef enum { TimeOut, Sync, None } FineTimeCtrl deriving (Eq,Bits);

typedef struct {
   Sample sample;
   FineTimeCtrl ctrl;
   LongCorrelation corr;
} PacketSync deriving (Bits);

typedef struct {
   Sample data;
   union tagged {
      void TimeOut;
      void None;
      LongCorrelation Sync;
   } ctrl;
} FineTimeOut deriving (Bits);


interface StatefulSynchronizer;
   interface Synchronizer#(2, 14) synchronizer;
//   method ControlType controlState;
//   interface ReadOnly#(CoarPowType) coarPow;
endinterface

module[ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkStatefulSynchronizer(StatefulSynchronizer);
   //input and output buffers
   FIFOF#(SynchronizerMesg#(SyncIntPrec,SyncFractPrec)) inQ <- mkLFIFOF;
   FIFOF#(UnserializerMesg#(SyncIntPrec,SyncFractPrec)) outQ <- mkSizedFIFOF(2);
 
   // delay new packet marker by 1 cycle
   Reg#(Bool) detectDelay <- mkReg(False);

   // modules
   PacketDetector detector <- mkPacketDetector;
   FreqEstimator freqEstimator <- mkFreqEstimator;
   FineTimeEstimator fineTime <- mkFineTimeEstimator;

   //mkConnection(toGet(inQ), detector.in);
   //mkConnection(freqEstimator.out, fineTime.in);

   Reg#(Bit#(32)) cycle <- mkReg(0);

   rule count;
      cycle <= cycle + 1;
   endrule

   //rule debug;
   //   $display("cycle %d inQ empty=%d outQ full=%d", cycle,
   //      !inQ.notEmpty, !outQ.notFull);
   //endrule

   rule run;
      //$display("run %d inQ", cycle);
      detector.in.put(inQ.first);
      inQ.deq();
   endrule

   Reg#(Bit#(32)) stsCount <- mkReg(0);

   rule pullDetect;
      //$display("pull detect %d", cycle);
      match tagged PacketDetect {
         sample: .sample,
         detect: .detect,
         corr: .corr
      } <- detector.out.get();

      freqEstimator.in.put(sample);

      if (detect)
        begin
          freqEstimator.coarseCorrIn.put(corr);

          if (`DEBUG_SYNCHRONIZER == 1)
            begin
              $display("STS DETECTED: %d (%d)", stsCount, cycle);
              //cmplxWrite("("," + ","i)",fxptWrite(7), sample);
              //$display("");
            end
        end

      stsCount <= stsCount + 1;
   endrule

   rule pullFreqEstimate;
      //$display("pull freq estimate %d", cycle);
      let out <- freqEstimator.out.get();
      fineTime.in.put(out);
   endrule

   rule pullFineTime;
      //$display("pull fine time %d", cycle);
      let out <- fineTime.out.get();

      case (out.ctrl) matches
         Sync:
           begin
             freqEstimator.fineCorrIn.put(out.corr);
             detector.restart();
           end
         TimeOut:
           begin
             detector.restart();
           end
      endcase

      outQ.enq(UnserializerMesg {
         control: SyncCtrl {
            isNewPacket: detectDelay,
            cpSize: CP0
         },
         data: out.sample
      });

      detectDelay <= (out.ctrl == Sync);
   endrule

   interface Synchronizer synchronizer;
     interface Put in;
      method Action put (SynchronizerMesg#(SyncIntPrec,SyncFractPrec) x);
         inQ.enq(x);
      endmethod
     endinterface
      
     interface out = toGet(outQ);
   endinterface 
   
//   method controlState = ctrlWire._read;
      
//   interface ReadOnly coarPow = timeEst.readCoarPow; 
endmodule
