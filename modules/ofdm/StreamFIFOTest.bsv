import StreamFIFO::*;
import Vector::*;

`define BufferSz 48
`define SSz      TLog#(TAdd#(`BufferSz,1))
`define MaxSSz   fromInteger(valueOf(`BufferSz))
`define DataSz   32
`define CntSz    TMul#(`BufferSz,`DataSz)

(* synthesize *)
module mkStreamFIFOTest(Empty);
   // state elements
   StreamFIFO#(`BufferSz,`SSz,Bit#(`DataSz)) fifos;
   fifos <- mkStreamLFIFO;
   Reg#(Bit#(`CntSz))      counter <- mkReg(0);
   Reg#(Bit#(`SSz))           inSz <- mkReg(1);
   Reg#(Bit#(`SSz))          outSz <- mkReg(1);
   Reg#(Bit#(32))         clockCnt <- mkReg(0);
   
   // rules
   rule enqData(fifos.notFull(inSz));
      counter <= counter + 1;
      fifos.enq(inSz,unpack(counter));
      $display("enq %d elements: %b free: %d",inSz,counter,fifos.free);
   endrule

   rule deqData(fifos.notEmpty(outSz));
      let data = fifos.first;
      fifos.deq(outSz);
      $display("deq %d elements: %b usage: %d",outSz,pack(data),fifos.usage);
   endrule

   rule advClock(True);
      inSz <= (inSz == `MaxSSz) ? 1 : inSz + 1;
      outSz <= (outSz == 1) ? `MaxSSz : outSz - 1;
      clockCnt <= clockCnt + 1;
      $display("clock: %d",clockCnt);
   endrule
   
   rule finish(clockCnt == 3000);
      $finish;
   endrule
endmodule

