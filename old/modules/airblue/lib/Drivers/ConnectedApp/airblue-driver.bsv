`include "asim/provides/low_level_platform_interface.bsh"
`include "asim/provides/soft_connections.bsh"
`include "asim/provides/common_services.bsh"
`include "asim/provides/hw_only_application.bsh"


module [CONNECTED_MODULE] mkConnectedApplication (); 
  //UserClock mainClock <- mkSoftClock(`AIRBLUE_CLOCK_FREQUENCY);  
  let hw <- mkHWOnlyApplication();
  return hw;
endmodule