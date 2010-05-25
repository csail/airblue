import FShow::*;
import Real::*;
import Vector::*;


// local includes
`include "asim/provides/airblue_types.bsh"

// C functions
import "BDPI" function Action update_softphy(Bit#(32) hint);
import "BDPI" function Action reset_softphy();
import "BDPI" function Bit#(64) average_ber();
import "BDPI" function Action display_ber();


typedef struct {
  Bit#(64) value;
} SoftPhyAvg;


//instance FShow#(SoftPhyAvg);
//  function Fmt fshow(SoftPhyAvg x);
//     return $format("%f", $bitstoreal(x.value));
//  endfunction
//endinstance


interface SoftHintAvg#(type n);
   method Action update(Vector#(n, SoftPhyHints) hints);
   method SoftPhyAvg average;
   method Action clear;
endinterface


module mkSoftHintAvg (SoftHintAvg#(n));

  method Action update(Vector#(n, SoftPhyHints) hints);
    for (Integer i = 0; i < valueof(n); i=i+1)
      begin
        update_softphy(extend(hints[i]));
      end
  endmethod

  method Action clear;
    `ifdef DEBUG_SOFTHINT
       $write("SoftHintAvg packet average ber: ");
       display_ber();
       $display("");
    `endif
    reset_softphy();
  endmethod

  method SoftPhyAvg average;
    let value = average_ber();
    return SoftPhyAvg { value: value };
  endmethod

endmodule
