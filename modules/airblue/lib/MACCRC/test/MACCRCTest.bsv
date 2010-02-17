import FIFO::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import LFSR::*;
import Connectable::*;
import FShow::*;

// import MACCRC::*;
// import DataTypes::*;
// import MACDataTypes::*;
// import ProtocolParameters::*;
// import MACPhyParameters::*;

// Local include
`include "asim/provides/airblue_mac_crc.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"

// (* synthesize *) 
// module mkMACCRCTest(Empty);
   
module mkHWOnlyApplication (Empty);   

   MACCRC maccrc <- mkMACCRC;
   FIFOF#(PhyData) turnFIFO <- mkSizedFIFOF(4096);
   FIFOF#(PhyData) expectedFIFO <- mkSizedFIFOF(4096);
   FIFOF#(BasicTXVector) vectorFIFO <- mkSizedFIFOF(1);
   FIFOF#(Bool) scrogFIFO <- mkFIFOF;
   Reg#(Bool) scrog <- mkReg(False);
   Reg#(PhyPacketLength) counter <- mkReg(0);
   Reg#(PhyPacketLength) macCounter <- mkReg(0);
   LFSR#(Bit#(8)) lfsr <- mkLFSR_8();
   Reg#(Bool) initialized <- mkReg(False);
   Reg#(Bit#(18)) rxCount <- mkReg(0);
   Reg#(Bit#(18)) count <- mkReg(0);

   // hook up physical side
   mkConnection(maccrc.phy_txdata,fifoToPut(fifofToFifo(turnFIFO)));
   mkConnection(maccrc.phy_txstart,fifoToPut(fifofToFifo(vectorFIFO)));
//   mkConnection(fifoToGet(turnFIFO),maccrc.phy_rxdata);
   rule printState;
     count <= count + 1;
     if(count[15:0] == 0)
       begin
         $display("Counter %d", counter);
         $display("Expected FIFO: ", fshow(expectedFIFO));
         $display("Turn FIFO: ", fshow(turnFIFO));
         $display("Vector FIFO: ", fshow(vectorFIFO));
         $display("scrog FIFO: ", fshow(vectorFIFO));
       end
   endrule   


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
     BasicRXVector vector = BasicRXVector {length:vectorFIFO.first.length,rate:vectorFIFO.first.rate};
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
     maccrc.mac_txstart.put(BasicTXVector{length:zeroExtend(lfsr.value),power:0,service:0,rate:R0, dst_addr: ?, src_addr: ?});
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

   rule drainAborts;
     let abort <- maccrc.mac_abort.get();
   endrule

endmodule