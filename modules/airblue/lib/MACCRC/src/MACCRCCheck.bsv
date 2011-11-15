import FIFO::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;
import FShow::*;

// import CRC::*;
// import CommitFIFO::*;
// import MACDataTypes::*;
// import ProtocolParameters::*;
// import MACPhyParameters::*;

// Local include
`include "asim/provides/crc.bsh"
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/librl_bsv_storage.bsh"


interface CRC_CHECKER#(type vector);
   // CRC <-> Phy
   interface Put#(vector)           phy_rxstart;   
   interface Put#(PhyData)            phy_rxdata;   

   // CRC <-> MAC
   interface Get#(Bool)       crc_passed;   

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

module mkCRCChecker (CRC_CHECKER#(vector_t))
   provisos (FShow#(vector_t), 
             HasByteLength#(vector_t, SizeOf#(PhyPacketLength)),
             Bits#(vector_t, vector_sz));

   Reg#(vector_t) rxvector <- mkReg(?);  
   Reg#(PhyPacketLength) length <- mkReg(0);
   Reg#(PhyPacketLength) counter <- mkReg(0);
   Reg#(CRCState) state <- mkReg(Idle);
   CRC#(Bit#(32),PhyData) crc <- mkParallelCRC(fromInteger(valueof(CRCPoly)),~0,LITTLE_ENDIAN_CRC);
   Reg#(Bit#(TLog#(TDiv#(SizeOf#(Bit#(32)),SizeOf#(PhyData)))))  crcCount <- mkReg(0);
   FIFO#(Bool) passedFIFO <- mkFIFO;
   Reg#(Bit#(16)) debugCounter <- mkReg(0);
   Bit#(32) expected = fromInteger(valueof(CRCPolyResult));
   

   rule checkDebug;
     debugCounter <= debugCounter + 1;
     if(debugCounter == 0 && `DEBUG_CRC_CHECKER == 1)
       begin
         $display("state", fshow(state));
         $display("rxvector", fshow(rxvector));
       end
   endrule

   rule handleRXCRC(state == RX && counter == length);
     // got all the TX data
     state <= Idle;
     if(reverseBits(crc.getRemainder) == fromInteger(valueof(CRCPolyResult)))
       begin
         passedFIFO.enq(True);  
         $display("CRC_CHECKER Packet RXed");
       end
     else 
       begin
         passedFIFO.enq(False);  
         if(`DEBUG_CRC_CHECKER == 1)
           begin
             $display("CRC_CHECKER Shooting down packet expected: %b %h, got %h %h %h %h", expected,expected, crc.getRemainder, ~crc.getRemainder,reverseBits(crc.getRemainder), ~reverseBits(crc.getRemainder)  );
           end
       end
   endrule


   interface Put phy_rxstart;
     method Action put(vector_t vector) if(state == Idle);
       length <= byteLength(vector);
       rxvector <= vector;
       state <= RX;
       counter <= 0;
       crcCount <= 0;
       crc.init;
     endmethod
   endinterface
   
   interface Put phy_rxdata;   
     method Action put(PhyData data) if(state == RX && counter < length);
       crc.inputBits(data);
       counter <= counter + 1;
  
       if(`DEBUG_CRC_CHECKER == 1)
         begin 
           $display("%m CRC_CHECKER RX data from PHY: %h",data);
           $display("CRC_CHECKER Status: %b %h, got %b %h %h %h %h", expected,expected,crc.getRemainder,crc.getRemainder,~crc.getRemainder,reverseBits(crc.getRemainder), ~reverseBits(crc.getRemainder) );
         end
     endmethod
   endinterface


   interface Get crc_passed = toGet(passedFIFO);
endmodule

