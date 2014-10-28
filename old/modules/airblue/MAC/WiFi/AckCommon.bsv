typedef struct {
   Bit#(48) ra;
   Bit#(16) dur_id;
} ACK_PARAMS deriving (Eq,Bits);

interface AckBuilder;

   // Generates an ACK with the given fields
   //  ra - RA field
   //  dur_id - Duration/ID field
   method Bit#(FrameSz) ack(ACK_PARAMS params);

endinterface
