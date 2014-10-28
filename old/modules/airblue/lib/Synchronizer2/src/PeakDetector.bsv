import GetPut::*;


typedef struct {
   Bit#(10) idx;
   Bit#(10) value;
} Peak deriving (Eq,Bits);


interface PeakDetector;
   method Action clear();
   method Bit#(10) index;
   method Vector#(2,Peak) peaks;
   method Action update(Bit#(10) x);
endinterface


module mkPeakDetector (PeakDetector);

   Reg#(Bit#(10)) counter <- mkReg(?);
   Vector#(2, Reg#(Peak)) peakRegs <- replicateM( mkReg(?) );

   RWire#(Bit#(10)) data <- mkRWire;
   PulseWire clearSignal <- mkPulseWire;

   rule updateState;
      if (clearSignal)
        begin
          counter <= 0;
          peakRegs[0] <= unpack(0);
          peakRegs[1] <= unpack(0);
        end
      else if (data.wget matches tagged Valid .x)
        begin
          if (x > peakRegs[0].value)
            begin
              peakRegs[1] <= peakRegs[0];
              peakRegs[0] <= Peak { idx: counter, value: x };
            end
          else if (x > peakRegs[1].value)
            begin
              peakRegs[1] <= Peak { idx: counter, value: x };
            end
          counter <= counter + 1;
        end
   endrule

   method Action clear();
      clearSignal.send();
   endmethod

   method Bit#(10) index;
      return counter;
   endmethod

   method Vector#(2, Peak) peaks;
      return readVReg(peakRegs);
   endmethod

   method Action update(Bit#(10) x);
      data.wset(x);
   endmethod

endmodule
