import FIFO::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;
import FShow::*;

// Local include
`include "awb/provides/crc.bsh"
`include "awb/provides/airblue_types.bsh"
`include "awb/provides/airblue_parameters.bsh"
`include "awb/provides/librl_bsv_storage.bsh"

interface MACCRC#(type rx_vector_t, type tx_vector_t);
   // CRC <-> Phy
   interface Get#(tx_vector_t)   phy_txstart;  
   interface Put#(rx_vector_t)   phy_rxstart;   
   interface Get#(PhyData)       phy_txdata;     
   interface Put#(PhyData)       phy_rxdata;   

   // CRC <-> MAC
   interface Put#(tx_vector_t)   mac_txstart;  
   interface Get#(rx_vector_t)   mac_rxstart;   
   interface Put#(PhyData)       mac_txdata;     
   interface Get#(PhyData)       mac_rxdata;   

   interface Get#(RXExternalFeedback) mac_abort;
endinterface

instance FShow#(CRCState);
  function Fmt fshow (CRCState state);
    case (state)
       Idle: return $format("Idle");
       RX: return $format("RX");
       TX: return $format("TX");
     endcase
  endfunction
endinstance

typedef enum {
  Idle,
  RX,
  TX
} CRCState deriving (Bits,Eq);

module mkMACCRC (MACCRC#(rx_vector_t, tx_vector_t))
   provisos (FShow#(rx_vector_t), 
             HasByteLength#(rx_vector_t, SizeOf#(PhyPacketLength)),
             Bits#(rx_vector_t, rx_vector_sz),
             FShow#(tx_vector_t),	     
             HasByteLength#(tx_vector_t, SizeOf#(PhyPacketLength)),
             Bits#(tx_vector_t, tx_vector_sz));

   Reg#(rx_vector_t) rxvector <- mkReg(?);  
   Reg#(tx_vector_t) txvector <- mkReg(?);  
   Reg#(PhyPacketLength) length <- mkReg(0);
   Reg#(PhyPacketLength) counter <- mkReg(0);
   Reg#(Bool)     rxFull <- mkReg(False); 
   Reg#(Bool)     txFull <- mkReg(False);
   Reg#(CRCState) state <- mkReg(Idle);
   CommitFIFO#(PhyData,4096) rxBuffer <- mkCommitFIFO;
   FIFOF#(PhyData) txBuffer <- mkFIFOF; // much smaller - could get rid of...
   CRC#(Bit#(32),PhyData) crc <- mkParallelCRC(fromInteger(valueof(CRCPoly)),~0, LITTLE_ENDIAN_CRC);
   Reg#(Bit#(TLog#(TDiv#(SizeOf#(Bit#(32)),SizeOf#(PhyData)))))  crcCount <- mkReg(0);
   FIFOF#(RXExternalFeedback) abortFIFO <- mkFIFOF;
 
   Reg#(Bit#(16)) debugCounter <- mkReg(0);

   rule checkDebug;
     debugCounter <= debugCounter + 1;
     if(debugCounter == 0 && `DEBUG_MACCRC == 1)
       begin
         $display("txBuffer", fshow(txBuffer));
         $display("state", fshow(state));
         $display("txvector", fshow(txvector));
         $display("rxvector", fshow(rxvector));
         $display("txFull", fshow(txFull));
         $display("rxFull", fshow(rxFull));
       end
   endrule

   rule handleTXzero(state == TX && counter >= length && counter < byteLength(txvector));
     counter <= counter + 1;
     $display("MACCRC TX Zero Insert");
     crc.inputBits(0);
   endrule

   rule handleTXCRC(state == TX && counter == byteLength(txvector));
     // got all the TX data
     Vector#(TDiv#(SizeOf#(Bit#(32)),SizeOf#(PhyData)), PhyData) crcVec= unpack(reverseBits((~fromInteger(valueof(CRCPolyResult)))^crc.getRemainder));
     crcCount <= crcCount + 1;
     if(crcCount + 1 == 0)
       begin
         state <= Idle;
       end
     if(`DEBUG_MACCRC == 1)
       begin
         $display("MACCRC TX: %h", crc.getRemainder);
         $display("MACCRC PacketTX: %b %h", ~reverseBits(crcVec[crcCount]),~reverseBits(crcVec[crcCount]));
       end
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
         if(debugCounter == 0 && `DEBUG_MACCRC == 1)
           begin
             $display("MACCRC Shooting down packet expected: %b %h, got %b", expected,expected,crc.getRemainder );
           end
         rxBuffer.abort;
         abortFIFO.enq(Abort);
       end
   endrule


   // CRC <-> Phy
   interface Get phy_txstart;  
     method ActionValue#(tx_vector_t) get() if(txFull);
       if(`DEBUG_MACCRC == 1)
         begin
           $display("TB Packet Past CRC");
         end
       txFull <= False;
       return txvector;
     endmethod
   endinterface

   interface Put phy_rxstart;
     method Action put(rx_vector_t vector) if(state == Idle && !rxFull);
       PhyPacketLength packetLength = byteLength(vector);
       rx_vector_t newVec = setByteLength(vector, packetLength - 4);
       length <= byteLength(vector);
       rxvector <= newVec;
       state <= RX;

       $display("TB MACCRC RX Vector start: %d",  packetLength);
       counter <= 0;
       crcCount <= 0;
       crc.init;
     endmethod
   endinterface
   
   interface Get phy_txdata;
      method ActionValue#(PhyData) get();
         let tx_data = txBuffer.first();
         txBuffer.deq();
         if(`DEBUG_MACCRC == 1)
           begin
             $display("%m MACCRC TX data to PHY: %h",tx_data);
           end
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
  
       if(`DEBUG_MACCRC == 1)
         begin 
           $display("%m MACCRC RX data from PHY: %h",data);
         end
     endmethod
   endinterface


   // CRC <-> MAC
   interface Put      mac_txstart;  
     method Action put(tx_vector_t vector) if(state == Idle && !txFull);
       crc.init();
       counter <= 0; 
       state <= TX;
       PhyPacketLength packetLength = byteLength(vector);
       if(`DEBUG_MACCRC == 1)
         begin
           $display("MACCRC TX Vector: %d",  packetLength);
         end
       length <= packetLength;
       tx_vector_t newVec = setByteLength(vector, packetLength + 4);
       txvector <= newVec;
       txFull <= True;
     endmethod
   endinterface

   interface Get mac_rxstart;   
     method ActionValue#(rx_vector_t) get() if(rxFull);
       rxFull <= False;
       PhyPacketLength packetLength = byteLength(rxvector);
       if(`DEBUG_MACCRC == 1)
         begin
           $display("TB MACCRC RX Vector finish: %d",  packetLength);
         end

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
   interface Get mac_abort = fifoToGet(fifofToFifo(abortFIFO));
endmodule

