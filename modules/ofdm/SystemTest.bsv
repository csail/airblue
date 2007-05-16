import DataTypes::*;
import Interfaces::*;
import RegFile::*;
import Transmitter::*;
import Complex::*;
import FixedPoint::*;
import Channel::*;
import RandomGen::*;
import Receiver::*;
import RegFile::*;
import RX_MAC::*;
import TX_Controller::*;

(* synthesize *)
module mkSystemTest(Empty);

   RandomGen#(64) randGen <- mkMersenneTwister(64'hB573AE980FF1134C);
   Reg#(Bit#(13))  length <- mkReg(0);   
   Reg#(Bit#(12)) counter <- mkReg(0);
   RegFile#(Bit#(12),Bit#(8)) regFile <- mkRegFileFull;
   Reg#(Bit#(16)) packetNo <- mkReg(0);
   
   Transmitter#(8,81) transmitter <- mkTransmitter_8_81();
   Channel#(81,1,15)      channel <- mkChannel_81_1_15();
   Receiver              receiver <- mkReceiver();
   RX_MAC                  rx_mac <- mkRX_MAC(regFile);

   rule enqHeader(length == 0);
   begin
      let randData <- randGen.genRand;
      let randRate = R4; // just test the top rate
//      let randRate = (randData[1:0] == 0) ? R1 : unpack(randData[1:0]);
//      let randLength = (randData[13:2] == 0) ? 1 : randData[13:2];
      Bit#(12) randLength = 1000;
      let header = TXMAC2ControllerInfo{rate: randRate, length: randLength};
      transmitter.getFromMAC(header);
      counter <= 0;
      packetNo <= packetNo + 1;
      length <= zeroExtend(randLength);
      $display("Going to send a  packet %d at rate:%d, length:%d",packetNo,randRate, randLength);
      if (packetNo == 101)
	$finish;
   end
   endrule
     
   rule enqData(True);
   begin
      let randData <- randGen.genRand; 
      let newData = Data{data: unpack(randData[7:0])};
      transmitter.getDataFromMAC(newData);
      counter <= counter + 1;
      length <= length - 1;
      regFile.upd(counter,randData[7:0]);
//      $display("data at position %d is 0x%h",counter,newData);
   end
   endrule

   rule dataToSend(True);
   begin
      let result <- transmitter.toAnalogTX();
      let resultVec = result.data;
      channel.fromTransmitter(result);
   end
   endrule

   rule receiverGetData(True);
   begin
      let result <- channel.toReceiver();
      receiver.fromAnalogRX(result);
   end
   endrule

   rule receiverLengthToRX_MAC(True);
   begin
      let result <- receiver.lengthToRX_MAC();
      rx_mac.fromRX_Controller(result);
   end
   endrule

   rule receiverDataToRX_MAC(True);
   begin
      let result <- receiver.dataToRX_MAC();
      rx_mac.fromDescrambler(result);
//      length <= (length > 2) ? length - 3 : 0;
   end
   endrule
      
endmodule  









