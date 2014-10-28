import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import CBus::*;

// import Register::*;
// import CBusUtils::*;

// import FPGAParameters::*;
// import ProtocolParameters::*;
// import MACDataTypes::*;
// import TXController::*;
// import RXController::*;
// import MACPhyParameters::*;

// local includes
`includes "asim/provides/airblue_parameters.bsh"
`includes "asim/provides/c_bus_utils.bsh"
`includes "asim/provides/register_library.bsh"

interface MacRate#(type ctrl_t_old, type ctrl_t_new);
  interface Server#(ctrl_t_old,ctrl_t_new) rateServer;
  method Action setRate(Rate rate);
endinterface


module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkMACRateSoftware (MacRate#(ctrl_t_old, ctrl_t_new))
   provisos (MutableRate#(ctrl_t_new, ctrl_t_old),
             Bits#(ctrl_t_old,crtl_t_old_sz),
             Bits#(ctrl_t_new,ctrl_t_new_sz));
   CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrMACRate  = CRAddr{a: fromInteger(valueof(AddrMACRate)) , o: 0};  

   Reg#(Rate) rateReg <-  mkCBRegR(addrMACRate,R0);
   FIFO#(ctrl_t_new) rateFIFO <- mkFIFO;

   interface Server rateServer;
     interface Put request;
       method Action put(ctrl_t_old req);
         rateFIFO.enq(mutateRate(req,rateReg));
       endmethod   
     endinterface  
     interface response = fifoToGet(rateFIFO);
   endinterface

   method Action setRate(Rate rate) = ?  ;
endmodule
