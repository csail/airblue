
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;


Bool crcDebug = False;

interface CRC#(type data, type in);
   method Action        inputBits(in bitIn);
   method data          getRemainder();
   method Action        init();
endinterface

module mkNaiveCRC#(Bit#(TAdd#(1,width)) initPoly, Bit#(width) initRem) (CRC#(Bit#(width),Bit#(1)))
   provisos(Add#(width, 1, TAdd#(1, width)));
   
   Reg#(Bit#(TAdd#(1,width)))  poly    <- mkReg(initPoly);
   Reg#(Bit#(width))           rem     <- mkReg(0);


   method Bit#(width)   getRemainder();
     return rem;
   endmethod      

   method Action init();
     rem <= initRem;
   endmethod

   method Action inputBits(Bit#(1) bitIn);
      Bit#(TAdd#(1,width)) new_rem = ({0,rem} << 1) | zeroExtend(bitIn);
      if(new_rem[valueof(width)]==1) // grab top bit
	 new_rem = new_rem ^ poly;
      if(`DEBUG_CRC > 1) 
        begin
          $display("CRC input %b rem %b new_rem %b poly %b init %b", bitIn, rem, new_rem, poly, initRem);
        end
      rem <= truncate(new_rem);     
   endmethod
   
endmodule

typedef enum {
 BIG_ENDIAN_CRC,
 LITTLE_ENDIAN_CRC
} CRCType deriving (Bits,Eq);

module mkParallelCRC#(Bit#(TAdd#(1,width)) initPoly, Bit#(width) initRem, CRCType endianess) (CRC#(Bit#(width),Bit#(in)))
   provisos(Add#(width, 1, TAdd#(1, width)),
            Add#(in, yyy, width),
            Mul#(xxx, in, width)
   );
   
   Reg#(Bit#(TAdd#(1,width)))  poly    <- mkReg(initPoly);
   Reg#(Bit#(width))           rem     <- mkReg(0);

   function Action bigEndianCRC(Bit#(in) bitIn);
     action
       Bit#(TAdd#(1,width)) new_rem = ?;
       Bit#(width) rem_temp = rem;
       for(Integer i = 0; i < valueof(in); i = i + 1)
         begin
           new_rem = {rem_temp, reverseBits(bitIn)[i]};           
           if(new_rem[valueof(width)]==1) // grab top bit
             begin
               new_rem = new_rem ^ poly;
             end
           rem_temp = truncate(new_rem);
         end

       Bit#(width) rem_trunc= truncate(new_rem);
       if(`DEBUG_CRC > 1) 
         begin
           $display("CRC input %b rem %b new_rem %b poly %b init %b", bitIn, rem, rem_trunc, poly, initRem);
         end
       rem <= truncate(new_rem);     
     endaction
   endfunction

   function Action littleEndianCRC(Bit#(in) bitIn);
     action
       Bit#(width) rem_temp = rem ^ zeroExtend(bitIn);
       for(Integer i = 0; i < valueof(in); i = i + 1)
         begin
           if(rem_temp[0]==1) // grab top bit
             begin
               rem_temp = (rem_temp >> 1) ^ truncateLSB(reverseBits(poly));
             end
           else
             begin 
              rem_temp = rem_temp >> 1; 
             end
       end

       rem <= rem_temp;     
     endaction
   endfunction

   method Bit#(width)   getRemainder();
     return rem;
   endmethod      

   method Action init();
     rem <= initRem;
   endmethod

   // silly unfolding, but whatever...
   // should probably do this as a foldr but i'm too lazy today.
   
   method Action inputBits(Bit#(in) bitIn);
     if(endianess == BIG_ENDIAN_CRC)
       begin
         bigEndianCRC(bitIn);
       end
     else
       begin
         littleEndianCRC(bitIn);
       end
   endmethod 
   
endmodule



