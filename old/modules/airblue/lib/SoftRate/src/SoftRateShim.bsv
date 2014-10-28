interface PacketBER;
   interface Put#(BasicRXVector) phy_rxstart;
   interface Put#(PhyHints) phy_rxhints;
   interface Get#(BitErrorRate) packet_ber;
endinterface


module mkPacketBER (PacketBER);

    FIFO#(BasicRXVector) rxStart <- mkFIFO;

    // calculates average bit-error-rate
    SoftHintAvg berCalc <- mkSoftHintAvg;

    // current octet index
    Reg#(PhyPacketLength) counter <- mkReg(0);

    interface Put phy_rxstart = toPut(rxStart);

    interface Put phy_rxhints;
       method Action put(PhyHints x);
          let rate = rxStart.first.rate;
          let length = rxStart.first.length;
          Bool last = (counter + 1 == length);

          if (last)
             $display("soft rate shim last:", length);

          berCalc.in.put(SoftHintMesg {
             rate: rate,
             hint: extend(head(x)),
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

    interface Get packet_ber = berCalc.out;

endmodule
