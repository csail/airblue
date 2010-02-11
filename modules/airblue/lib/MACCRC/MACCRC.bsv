import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;
import CRC::*;

import CommitFIFO::*;

import MACDataTypes::*;
import ProtocolParameters::*;
import TXController::*;
import RXController::*;
import MACPhyParameters::*;

interface MACCRC;
   // CRC <-> Phy
   interface Get#(BasicTXVector)      phy_txstart;  
   interface Put#(BasicRXVector)      phy_rxstart;   
   interface Get#(PhyData)       phy_txdata;     
   interface Put#(PhyData)       phy_rxdata;   

   // CRC <-> MAC
   interface Put#(BasicTXVector)      mac_txstart;  
   interface Get#(BasicRXVector)      mac_rxstart;   
   interface Put#(PhyData)       mac_txdata;     
   interface Get#(PhyData)       mac_rxdata;   

   interface Get#(RXExternalFeedback) mac_abort;
endinterface

typedef enum {
  Idle,
  RX,
  TX
} CRCState deriving (Bits,Eq);

(*synthesize*)
module mkMACCRC (MACCRC);

   Reg#(BasicRXVector) rxvector <- mkRegU;  
   Reg#(BasicTXVector) txvector <- mkRegU;  
   Reg#(PhyPacketLength) length <- mkReg(0);
   Reg#(PhyPacketLength) counter <- mkReg(0);
   Reg#(Bool)     rxFull <- mkReg(False); 
   Reg#(Bool)     txFull <- mkReg(False);
   Reg#(CRCState) state <- mkReg(Idle);
   CommitFIFO#(PhyData,4096) rxBuffer <- mkCommitFIFO;
   FIFO#(PhyData) txBuffer <- mkFIFO; // much smaller - could get rid of...
   CRC#(Bit#(32),PhyData) crc <- mkParallelCRC(fromInteger(valueof(CRCPoly)),~0);
   Reg#(Bit#(TLog#(TDiv#(SizeOf#(Bit#(32)),SizeOf#(PhyData)))))  crcCount <- mkReg(0);
   FIFO#(RXExternalFeedback) abortFIFO <- mkFIFO;
 
   rule checkFIFOFull (!rxBuffer.notFull);
     $display("TB MACCRC Warning rxBufferFull");
   endrule

   rule handleTXzero(state == TX && counter >= length && counter < txvector.length);
     counter <= counter + 1;
     $display("MACCRC TX Zero Insert");
     crc.inputBits(0);
   endrule

   rule handleTXCRC(state == TX && counter == txvector.length);
     // got all the TX data
     Vector#(TDiv#(SizeOf#(Bit#(32)),SizeOf#(PhyData)), PhyData) crcVec= unpack(reverseBits((~fromInteger(valueof(CRCPolyResult)))^crc.getRemainder));
     crcCount <= crcCount + 1;
     if(crcCount + 1 == 0)
       begin
         state <= Idle;
       end
     $display("MACCRC TX: %h", crc.getRemainder);
     $display("MACCRC PacketTX: %b %h", ~reverseBits(crcVec[crcCount]),~reverseBits(crcVec[crcCount]));
     txBuffer.enq(~reverseBits(crcVec[crcCount]));
   endrule   


   rule handleRXCRC(state == RX && counter == length);
     // got all the TX data
     state <= Idle;
     if(crc.getRemainder == fromInteger(valueof(CRCPolyResult)))
       begin
         rxBuffer.commit;
         rxFull <= True; 
         $display("MACCRC Packet RXed");
       end
     else 
       begin
         Bit#(32) expected = fromInteger(valueof(CRCPolyResult));
         $display("MACCRC Shooting down packet expected: %b %h, got %b", expected,expected,crc.getRemainder );
         rxBuffer.abort;
         abortFIFO.enq(Abort);
       end
   endrule


   // CRC <-> Phy
   interface Get phy_txstart;  
     method ActionValue#(BasicTXVector) get() if(txFull);
       $display("TB Packet Past CRC");
       txFull <= False;
       return txvector;
     endmethod
   endinterface

   interface Put phy_rxstart;
     method Action put(BasicRXVector vector) if(state == Idle && !rxFull);
       BasicRXVector newVec = vector;
       newVec.length = newVec.length - 4;
       length <= vector.length;
       rxvector <= newVec;
       state <= RX;
       $display("TB MACCRC RX Vector start: %d",  vector.length);
       counter <= 0;
       crcCount <= 0;
       crc.init;
     endmethod
   endinterface
   
   interface Get phy_txdata;
      method ActionValue#(PhyData) get();
         let tx_data = txBuffer.first();
         txBuffer.deq();
         $display("%m MACCRC TX data to PHY: %h",tx_data);
         return tx_data;
      endmethod
   endinterface

   interface Put phy_rxdata;   
     method Action put(PhyData data) if(state == RX && counter < length);
       crc.inputBits(data);
       counter <= counter + 1;
       if(counter < length - 4) // last 4 are CRC...
         begin
           rxBuffer.enq(data);
         end   
        $display("%m MACCRC RX data from PHY: %h",data);
     endmethod
   endinterface


   // CRC <-> MAC
   interface Put      mac_txstart;  
     method Action put(BasicTXVector vector) if(state == Idle && !txFull);
       crc.init();
       counter <= 0; 
       state <= TX;
       $display("MACCRC TX Vector: %d",  vector.length);
       length <= vector.length;
       BasicTXVector newVec = vector;
       newVec.length = newVec.length + 4;
       txvector <= newVec;
       txFull <= True;
     endmethod
   endinterface

   interface Get mac_rxstart;   
     method ActionValue#(BasicRXVector) get() if(rxFull);
       rxFull <= False;
       $display("TB MACCRC RX Vector finish: %d",  rxvector.length);
       return rxvector;
     endmethod
   endinterface

   interface Put mac_txdata;
     method Action put(PhyData data) if(state == TX && counter < length);
       crc.inputBits(data);
       counter <= counter + 1;
       txBuffer.enq(data);
     endmethod
   endinterface
      
   interface Get mac_rxdata = commitFifoToGet(rxBuffer);   
   interface Get mac_abort = fifoToGet(abortFIFO);
endmodule

