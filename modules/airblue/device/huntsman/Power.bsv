import CBus::*;

//import FPGAParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"


interface PowerCtrlWires;
 (* always_ready, always_enabled, prefix="", result="power_vbus" *) 
  method Bit#(1) powerVBUS();
 (* always_ready, always_enabled, prefix="", result="power_pa" *) 
  method Bit#(1) powerPA();  
endinterface


module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkPowerCtrl (PowerCtrlWires);
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrPowerPA = CRAddr{a: fromInteger(valueof(AddrPowerPA)) , o: 0};
  Reg#(Bit#(1)) powerVBUSReg <- mkReg(1);
  Reg#(Bit#(1)) powerPAReg <- mkCBRegRW(addrPowerPA,1);

  method powerVBUS = powerVBUSReg._read;
  method powerPA = powerPAReg._read;  
endmodule