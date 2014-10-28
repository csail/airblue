import CBus::*;

//import FPGAParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"


interface BOARD_WIRES;
 (* always_ready, always_enabled, prefix="", result="power_vbus" *) 
  method Bit#(1) powerVBUS();
 (* always_ready, always_enabled, prefix="", result="power_pa" *) 
  method Bit#(1) powerPA();  
endinterface

interface BOARD_DRIVER;
endinterface 

interface BOARD_DEVICE;
  BOARD_WIRES  power_wires;
  BOARD_DRIVER power_driver;
endinterface

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkBoard (BOARD_DEVICE);
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrPowerPA = CRAddr{a: fromInteger(valueof(AddrPowerPA)) , o: 0};
  Reg#(Bit#(1)) powerVBUSReg <- mkReg(1);
  Reg#(Bit#(1)) powerPAReg <- mkCBRegRW(addrPowerPA,1);

  interface BOARD_WIRES power_wires;
    method powerVBUS = powerVBUSReg._read;
    method powerPA = powerPAReg._read;  
  endinterface

  interface BOARD_DRIVER power_driver = ?;
endmodule