import FIFO::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import CRC::*;

module mkHWOnlyApplication(Empty);
   
   CRC#(Bit#(1),Bit#(1)) crc <- mkNaiveCRC('b11,'b0);
   CRC#(Bit#(1),Bit#(1)) crcPar <- mkParallelCRC('b11,'b0, BIG_ENDIAN_CRC);
   Reg#(Bool) done <- mkReg(False);
   Reg#(Bit#(10)) i <- mkReg(0);
   Reg#(Bit#(10)) j <- mkReg(0);
   
   Stmt test_seq = 
   seq
      for(i <= 0; i < 900; i <= i + 1)
        seq
          crc.init();
          crcPar.init();
          for(j <= 0; j < 10; j <= j + 1)
             seq
              crc.inputBits(i[j]);
              crcPar.inputBits(i[j]);
             endseq          
          if(zeroExtend(i[9] ^ i[8] ^ i[7] ^ i[6] ^ i[5] ^ i[4] ^ i[3] ^ i[2] ^ i[1] ^ i[0]) != crc.getRemainder)
            seq
              $display("Parity Mismatch: %d expected: %d got: %d", i,i[9] ^ i[8] ^ i[7] ^ i[6] ^ i[5] ^ i[4] ^ i[3] ^ i[2] ^ i[1] ^ i[0],crc.getRemainder[0]);
              $display("FAIL");
              $finish;
            endseq
          if(zeroExtend(i[9] ^ i[8] ^ i[7] ^ i[6] ^ i[5] ^ i[4] ^ i[3] ^ i[2] ^ i[1] ^ i[0]) != crcPar.getRemainder)
            seq
              $display("Parity Mismatch: %d expected: %d got: %d", i,i[9] ^ i[8] ^ i[7] ^ i[6] ^ i[5] ^ i[4] ^ i[3] ^ i[2] ^ i[1] ^ i[0],crcPar.getRemainder[0]);
              $display("FAIL");
              $finish;
            endseq
        endseq

      
      $display("PASS");
      $finish; 
   endseq;


   
   FSM test_fsm <- mkFSM(test_seq);
   
   rule do_stuff (!done);
      test_fsm.start();
      done <= True;
   endrule

   
endmodule