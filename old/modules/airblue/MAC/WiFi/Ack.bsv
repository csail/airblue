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

typedef Bit#(FrameSz) Frame;

interface FrameDecode;

   method Integer size(FrameCtl_T ctl);

   //method Maybe#(MacFrame_T) decode(Frame frame, FrameCtl_T frame_ctrl,
   //   PhyPacketLength len);

endinterface
