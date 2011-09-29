import GetPut::*;
import LFSR::*;
import FIFO::*;
import FIFOF::*;
import StmtFSM::*;

// Local includes
`include "asim/provides/airblue_crc_checker.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/clocks_device.bsh"
`include "asim/rrr/remote_server_stub_PACKETCHECKRRR.bsh"
`include "asim/provides/librl_bsv_storage.bsh"
`include "asim/provides/librl_bsv_base.bsh"
`include "asim/provides/fpga_components.bsh"

interface PacketCheck;
  // for hooking up to the baseband
  interface Put#(RXVector) rxVector;
  interface Put#(Bit#(8))  rxData;
  interface Put#(Bit#(0))  abortAck;
  interface Get#(Bit#(0))  abortReq; 
endinterface

typedef enum {
  RRR, 
  DataPath
} ByteBERToken deriving (Bits,Eq);

// this one only checks packets for correctness, not 
// for sequence errors - might want to do that at some point
// even if it takes a while to re-sync
module [CONNECTED_MODULE] mkPacketCheck (PacketCheck);

 ServerStub_PACKETCHECKRRR serverStub <- mkServerStub_PACKETCHECKRRR();

 MEMORY_IFC#(Bit#(12),Bit#(8))  expectedPacket <- mkBRAM();
 MEMORY_IFC#(Bit#(12),Bit#(32)) byteBER        <- mkBRAM();
 LUTRAM#(Bit#(8),Bit#(32))  totalBER           <- mkLUTRAMU();

 Reg#(Bit#(12)) size  <- mkReg(0); 
 Reg#(Bit#(12)) expectedSize  <- mkReg(0); 
 Reg#(Bit#(13)) count <- mkReg(0);
 Reg#(Bit#(12)) expectedIndex <- mkReg(0);

 FIFO#(RXVector) rxVectorFIFO <- mkFIFO; 
 FIFO#(Bit#(8))  rxDataFIFO <- mkFIFO; 
 FIFO#(Bit#(8))  rxTransferFIFO <- mkFIFO; 
 FIFO#(Bit#(0))  abortReqFIFO <- mkFIFO;
 FIFO#(Bit#(0))  abortAckFIFO <- mkFIFO;  
 FIFOF#(ByteBERToken)  byteBERFIFO <- mkFIFOF;  

 CRC_CHECKER crcChecker <- mkCRCChecker;

 Reg#(Bit#(32)) packetsRXReg <- mkReg(0);
 Reg#(Bit#(32)) packetsCorrectReg <- mkReg(0);
 Reg#(Bit#(32)) bytesRXCorrectReg <- mkReg(0);
 Reg#(Bit#(32)) mismatchedLengthCount <- mkReg(0);
 Reg#(Bit#(32)) passedCRC <- mkReg(0);
 Reg#(Bit#(32)) matchedLengthCount <- mkReg(0);
 Reg#(Bit#(32)) bytesRXReg <- mkReg(0);
 Reg#(Bit#(32)) cycleCountReg <- mkReg(0);
 Reg#(Bit#(32)) packetBerReg <- mkReg(0); // packetwise ber  
 Reg#(Bit#(32)) berReg <- mkReg(0);
 Reg#(Bool) packetError <- mkReg(False);
 Reg#(Bool) initialized <- mkReg(False);

 Reg#(Bool)     mismatchedLength <- mkReg(False);

 rule getBER;
   let dummy <- serverStub.acceptRequest_GetBER();
   serverStub.sendResponse_GetBER(berReg);
 endrule

 rule getPacketRX;
   let dummy <- serverStub.acceptRequest_GetPacketsRX();
   serverStub.sendResponse_GetPacketsRX(packetsRXReg);
 endrule

 rule getBytesRX;
   let dummy <- serverStub.acceptRequest_GetBytesRX();
   serverStub.sendResponse_GetBytesRX(bytesRXReg);
 endrule

 rule getBytesRXCorrect;
   let dummy <- serverStub.acceptRequest_GetBytesRXCorrect();
   serverStub.sendResponse_GetBytesRXCorrect(bytesRXCorrectReg);
 endrule

 rule getPassedCRC;
   let dummy <- serverStub.acceptRequest_GetPassedCRC();
   serverStub.sendResponse_GetPassedCRC(passedCRC);
 endrule

 rule getPacketRXCorrect;
   let dummy <- serverStub.acceptRequest_GetPacketsRXCorrect();
   serverStub.sendResponse_GetPacketsRXCorrect(packetsCorrectReg);
 endrule

 rule getMismatchRX;
   let dummy <- serverStub.acceptRequest_GetMismatchedRX();
   serverStub.sendResponse_GetMismatchedRX(mismatchedLengthCount);
 endrule

 rule geMatchRX;
   let dummy <- serverStub.acceptRequest_GetMatchedRX();
   serverStub.sendResponse_GetMatchedRX(matchedLengthCount);
 endrule

 rule setData;
   let bramCommand <- serverStub.acceptRequest_SetExpectedByte();
   expectedPacket.write(truncate(bramCommand.addr), bramCommand.value);
 endrule

 rule setExpectedLength;
   let length <- serverStub.acceptRequest_SetExpectedLength();
   expectedSize <= truncate(length);
 endrule

 rule getByteBER;
   let bramIndex <- serverStub.acceptRequest_GetByteBER();
   byteBER.readReq(truncate(bramIndex));   
   byteBERFIFO.enq(RRR);
 endrule

 rule returnBER(byteBERFIFO.first == RRR);
   let byteResp <- byteBER.readRsp();
   byteBERFIFO.deq;
   serverStub.sendResponse_GetByteBER(byteResp);
 endrule 

 rule getTotalBER;
   let lutIndex <- serverStub.acceptRequest_GetTotalBER();
   serverStub.sendResponse_GetTotalBER(totalBER.sub(truncate(lutIndex)));
 endrule


 rule cycleTick;
   cycleCountReg <= cycleCountReg + 1;
 endrule

 rule init(!initialized);
    if(count + 1 == 0) 
      begin
        initialized <= True;
      end
    byteBER.write(truncate(count),0);   
    totalBER.upd(truncate(count),0);
    count <= count + 1;
 endrule

 rule startPacketCheck(count == 0 && initialized);
   rxVectorFIFO.deq;
   crcChecker.phy_rxstart.put(rxVectorFIFO.first);
   size <= rxVectorFIFO.first.header.length;
   expectedIndex <= 0;
   count <= 1;
   if(`DEBUG_PACKETCHECK == 1)
     begin
       $display("PacketCheck: starting packet check size: %d @ %d", rxVectorFIFO.first.header.length, cycleCountReg);
     end
   
 endrule
   
   
 rule deqAbortAck(True);
      abortAckFIFO.deq;
 endrule
   
 rule receiveData(count > 0 && count <= zeroExtend(size));
      rxDataFIFO.deq;
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: rxDataFIFO.first %d",rxDataFIFO.first);
        end
      crcChecker.phy_rxdata.put(rxDataFIFO.first);
      count <= count + 1;

      if(size != expectedSize)
        begin 
          if(count == zeroExtend(size))
            begin
              mismatchedLengthCount  <=  mismatchedLengthCount + 1;
            end
        end      
      else
        begin                      
            expectedPacket.readReq(truncate(count - 1));           
            byteBER.readReq(truncate(count - 1));
            rxTransferFIFO.enq(rxDataFIFO.first);                        
            byteBERFIFO.enq(DataPath);
         end
 endrule

 rule checkData(byteBERFIFO.first == DataPath);
   let expected <- expectedPacket.readRsp();
   let byteBERPrev <- byteBER.readRsp();
   byteBERFIFO.deq();
   rxTransferFIFO.deq;
   Bit#(32) thisBER = zeroExtend(pack(countOnes(expected^rxTransferFIFO.first())));
   byteBER.write(expectedIndex,byteBERPrev + thisBER);    
   expectedIndex <= expectedIndex + 1;
   packetBerReg <= packetBerReg + thisBER;
   berReg <= berReg + thisBER;
 endrule
   
   rule checkCheckSum(count > 0 && (count == zeroExtend(size) + 1) && !byteBERFIFO.notEmpty);
      packetsRXReg <= packetsRXReg + 1;
      bytesRXReg <= bytesRXReg + zeroExtend(size);   
      count <= 0;
      packetBerReg <= 0; // reset packetwise ber

      let crcResult <- crcChecker.crc_passed.get();

      if(crcResult == True) 
        begin 
          $display("Got a passed CRC");
          passedCRC <= passedCRC + 1;
          bytesRXCorrectReg <= bytesRXCorrectReg + zeroExtend(size);
        end

      if(size == expectedSize)
        begin
          matchedLengthCount  <=  matchedLengthCount + 1;
          if(packetBerReg  < 128)
            begin
              totalBER.upd(truncate(packetBerReg),totalBER.sub(truncate(packetBerReg)) + 1);           
            end
          else
            begin
              totalBER.upd(63,totalBER.sub(truncate(packetBerReg)) + 1);   
            end
  
         if(packetBerReg == 0) 
           begin

             packetsCorrectReg <= packetsCorrectReg + 1;

            if(`DEBUG_PACKETCHECK == 1)
              begin
                $display("PacketCheck: receive packet count %d", packetsCorrectReg + 1);             
                $display("PacketCheck: total bytes: %d", bytesRXReg + zeroExtend(size));
                $display("PacketCheck: correctly received %d of %d packets @ %d",packetsCorrectReg,packetsRXReg,cycleCountReg);
              end
           end               
        else 
           begin
              $display("PacketCheck: ERROR bad packet");
//            $finish;
           end  
      end
	   
      if(`DEBUG_PACKETCHECK == 1)
        begin
          $display("PacketCheck: Packet bit errors: %d, Packet bit length: %d, BER total: %d", packetBerReg, size*8, berReg);
        end

   endrule

  

  interface rxVector = fifoToPut(rxVectorFIFO);
  interface rxData = fifoToPut(rxDataFIFO);
  interface abortReq = fifoToGet(abortReqFIFO);
  interface abortAck = fifoToPut(abortAckFIFO);    

endmodule