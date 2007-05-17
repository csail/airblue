import FIFO::*;
import GetPut::*;

import ofdm_common::*;
import ofdm_types::*;
import ofdm_arith_library::*;
import ofdm_base::*;

// import Interfaces::*;
// import DataTypes::*;
// import Controls::*;

module mkChannelEstimator#(function Symbol#(out_n,i_prec,f_prec) pilotRemover(Symbol#(in_n,i_prec, f_prec) in))
   (ChannelEstimator#(ctrl_t,in_n,out_n,i_prec,f_prec))
    provisos (Bits#(ctrl_t, ctrl_sz));

    FIFO#(ChannelEstimatorMesg#(ctrl_t,in_n,i_prec,f_prec)) inQ <- mkLFIFO;
    FIFO#(DemapperMesg#(ctrl_t,out_n,i_prec,f_prec))       outQ <- mkSizedFIFO(2);

    rule process(True);
        inQ.deq();
        let mesg = inQ.first();
        let processedData = pilotRemover(mesg.data);
        outQ.enq(Mesg{control: mesg.control, data: processedData});
    endrule

    interface in  = fifoToPut(inQ);
    interface out = fifoToGet(outQ);
endmodule
