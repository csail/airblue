import FIFO::*;
import FIFOF::*;
import DataTypes::*;
import GetPut::*;
import StmtFSM::*;
import MACCRC::*;
import LFSR::*;
import Connectable::*;

import MACDataTypes::*;
import ProtocolParameters::*;
import TXController::*;
import RXController::*;

(* synthesize *) 
module mkMACCRCTest(Empty);
   
   MACCRC maccrc <- mkMACCRC;
   FIFO#(PhyData) turnFIFO <- mkSizedFIFO(4096);
   FIFO#(PhyData) expectedFIFO <- mkSizedFIFO(4096);
   FIFO#(TXVector) vectorFIFO <- mkSizedFIFO(4);
   FIFO#(Bool) scrogFIFO <- mkFIFO;
   Reg#(Bool) scrog <- mkReg(False);
   Reg#(PhyPacketLength) counter <- mkReg(0);
   Reg#(PhyPacketLength) macCounter <- mkReg(0);
   LFSR#(Bit#(8)) lfsr <- mkLFSR_8();
   Reg#(Bool) initialized <- mkReg(False);
   Reg#(Bit#(18)) rxCount <- mkReg(0);

   // hook up physical side
   mkConnection(maccrc.phy_txdata,fifoToPut(turnFIFO));
   mkConnection(maccrc.phy_txstart,fifoToPut(vectorFIFO));
//   mkConnection(fifoToGet(turnFIFO),maccrc.phy_rxdata);
   
   rule turnRXData(counter != 0);
     $display("turn RX data");
     counter <= counter - 1;
     if(counter - 1 == 0)
       begin 
         $display("deq TX data");
         vectorFIFO.deq;
       end
     if(counter > vectorFIFO.first.length)
       begin
         maccrc.phy_rxdata.put(0); // put in an extra        
       end   
     else
       begin
         maccrc.phy_rxdata.put(turnFIFO.first);
         turnFIFO.deq; 
       end
   endrule

  rule turnRXVector(counter == 0);
     $display("TB turn RX vector: ");
     scrogFIFO.deq;
     RXVector vector = RXVector {length:vectorFIFO.first.length,rate:vectorFIFO.first.rate};
     if(scrogFIFO.first) 
       begin
         $display("TB we intend to shoot down: %d", vectorFIFO.first.length + 1 );
         counter <= vectorFIFO.first.length + 1;
         vector.length = vectorFIFO.first.length + 1;
       end
     else
       begin
         $display("TB we intend to pass: %d", vectorFIFO.first.length );
         counter <= vectorFIFO.first.length;
         vector.length = vectorFIFO.first.length;
       end
 

     maccrc.phy_rxstart.put(vector);
   endrule

   rule init(!initialized);
     initialized <= True;
     lfsr.seed(1);
   endrule

   rule stuffNew(initialized && macCounter == 0);
     scrogFIFO.enq(scrog);
     lfsr.next;
     maccrc.mac_txstart.put(TXVector{length:zeroExtend(lfsr.value),power:0,service:0,rate:R0});
     macCounter <= zeroExtend(lfsr.value);     
   endrule

   rule stuffData(initialized && macCounter != 0);
     if(!scrog) 
       begin
         expectedFIFO.enq(lfsr.value);
       end        
     macCounter <= macCounter - 1;
     if(macCounter - 1 == 0)
       begin
         scrog <= !scrog;  
       end
     lfsr.next;
     maccrc.mac_txdata.put(lfsr.value);
   endrule   
   
   rule deqRX;
     let vec <- maccrc.mac_rxstart.get;
   endrule

   rule checkData;
    rxCount <= rxCount + 1; 
    expectedFIFO.deq;
    let data <- maccrc.mac_rxdata.get;
    if(expectedFIFO.first != data)
      begin 
        $display("ERROR: expected: %h got: %h", expectedFIFO.first, data);
        $finish;
      end
    else 
      begin
        $display("expected: %h got: %h", expectedFIFO.first, data);
      end

    if(rxCount + 1 == 0)
      begin
        $display("PASS");
        $finish;
      end
   endrule 

endmodule