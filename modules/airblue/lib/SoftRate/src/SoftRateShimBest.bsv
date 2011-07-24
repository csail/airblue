import FIFOF::*;

interface PacketBER;
   interface Put#(BasicRXVector) phy_rxstart;
   interface Put#(PhyHints) phy_rxhints;
   interface Get#(BitErrorRate) packet_ber;
endinterface


module mkPacketBER (PacketBER);

    FIFOF#(BasicRXVector) rxStart <- mkFIFOF;

    // calculates average bit-error-rate
    SoftHintAvg berCalc <- mkSoftHintAvg;

    // current octet index
    Reg#(PhyPacketLength) counter <- mkReg(0);

    interface Put phy_rxstart = toPut(rxStart);

    interface Put phy_rxhints;
       method Action put(PhyHints x);
          let rate = rxStart.first.rate;
          // soft hints include hints for service field
          let length = rxStart.first.length + 2;
          Bool last = (counter + 1 == length);

          if (last)
             $display("soft rate shim last:", length);

          //$write(" HINTS: ");
          //for (Integer i = 0; i < 8; i=i+1)
          //  begin
          //    $write("%d ", x[i]);
          //  end
          //$display("");

          berCalc.in.put(SoftHintMesg {
             rate: rate,
             hints: x,
             isLast: last
          });

          if (last)
            begin
              rxStart.deq();
              counter <= 0;
            end
          else
            begin
              counter <= counter + 1;
            end
       endmethod
    endinterface

    interface Get packet_ber;
       method ActionValue#(BitErrorRate) get;
          let ber <- berCalc.out.get();
          $display("soft rate shim ber: %d", ber);
          return ber;
       endmethod
    endinterface

endmodule
