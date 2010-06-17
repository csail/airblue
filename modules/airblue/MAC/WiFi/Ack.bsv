
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

module mkAckBuilder(AckBuilder);

   method Bit#(FrameSz) ack(ACK_PARAMS params);
      FrameCtl_T frame_ctl = unpack(0);
      frame_ctl.type_val = Control;
      frame_ctl.subtype_val = 4'b1101;//`FRAME_CTL_SUBTYPE_ACK;
      frame_ctl.to_ds = 0;
      frame_ctl.from_ds = 0;

      let a = CommonCtlFrame1_T {
         frame_ctl: frame_ctl,
         dur: params.dur_id,
         ra: params.ra
      };

      return packFrame(a);
   endmethod

endmodule

`include "asim/provides/airblue_softhint_avg.bsh"

interface SoftRateAckBuilder;
   interface AckBuilder ack;
   interface Put#(BitErrorRate) ber;
endinterface

module mkSoftRateAckBuilder (SoftRateAckBuilder);

   Reg#(BitErrorRate) berReg <- mkReg(0);

   interface AckBuilder ack;
      method Bit#(FrameSz) ack(ACK_PARAMS params);
         FrameCtl_T frame_ctl = unpack(0);
         frame_ctl.type_val = Control;
         frame_ctl.subtype_val = 4'b0101;//`FRAME_CTL_SUBTYPE_SR_ACK;
         frame_ctl.to_ds = 0;
         frame_ctl.from_ds = 0;

         let sra = SoftRateAck {
            frame_ctl: frame_ctl,
            dur: params.dur_id,
            ra: params.ra,
            avg_ber: truncate(pack(berReg))
         };

         return packFrame(sra);
      endmethod
   endinterface

   interface ber = toPut(asReg(berReg));

endmodule

/// ------

typedef Bit#(FrameSz) Frame;

interface FrameDecode;

   method Integer size(FrameCtl_T ctl);

   //method Maybe#(MacFrame_T) decode(Frame frame, FrameCtl_T frame_ctrl,
   //   PhyPacketLength len);

endinterface
