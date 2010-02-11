import FIFO::*;
import LFSR::*;
import GetPut::*;
import ClientServer::*;

import MagnitudeEstimator::*;


(* synthesize *)
module mkMagnitudeEstimatorTest (Empty);
  LFSR#(Bit#(32)) lfsr <- mkLFSR_32;
  MagnitudeEstimator#(32) estimator <- mkMagnitudeEstimator;
  RWire#(Bit#(6)) expectedMagnitude <- mkRWire;
  Reg#(Bool) initialized <- mkReg(False);
  Reg#(Bit#(20)) count <- mkReg(~0);

  rule init(!initialized);
    lfsr.seed(1);
    initialized <= True;
  endrule

  rule testEstimator;
    $display("Estimating %h", lfsr.value);
    for(Integer i = 31; i >= 0; i=i-1)
      begin
        if(lfsr.value[i] == 1) 
          begin
            expectedMagnitude.wset(fromInteger(i+1));
            i = -1;
          end
        else if(i == 0)
          begin
            expectedMagnitude.wset(0);
          end
      end

    lfsr.next;
    estimator.request.put(lfsr.value);
  endrule

  rule checkResult;
    count <= count - 1;
    let result <- estimator.response.get;
    if(fromMaybe(0,expectedMagnitude.wget) != result)
      begin
        $display("Error: got %d, expected %d", fromMaybe(0,expectedMagnitude.wget), result);
        $finish;
      end
    if(count - 1 == 0) 
      begin
        $display("PASS");
        $finish;
      end
  endrule
  
endmodule