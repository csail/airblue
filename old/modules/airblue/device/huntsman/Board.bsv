import CBus::*;
import Clocks::*;


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
  interface BOARD_WIRES  board_wires;
  interface BOARD_DRIVER board_driver;
endinterface

module [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkBoard (BOARD_DEVICE);
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrPowerPA = CRAddr{a: fromInteger(valueof(AddrPowerPA)) , o: 0};
  Reg#(Bit#(1)) powerVBUSReg <- mkReg(1);
  ReadOnly#(Bit#(1)) powerVBUSRegExtern <- mkNullCrossingWire(noClock(), powerVBUSReg);
  Reg#(Bit#(1)) powerPAReg <- mkCBRegRW(addrPowerPA,1);
  ReadOnly#(Bit#(1)) powerPARegExtern <- mkNullCrossingWire(noClock(), powerPAReg);

  interface BOARD_WIRES board_wires;
    method powerVBUS = powerVBUSRegExtern._read;
    method powerPA = powerPARegExtern._read;  
  endinterface

  interface BOARD_DRIVER board_driver = ?;
endmodule