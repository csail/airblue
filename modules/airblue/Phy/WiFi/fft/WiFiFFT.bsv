import Connectable::*;
import FIFO::*;
import GetPut::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_fft_library.bsh"
//`include "asim/provides/airblue_transmitter.bsh"
//`include "asim/provides/airblue_receiver.bsh"
`include "asim/provides/soft_services.bsh"
`include "asim/provides/soft_connections.bsh"

(* synthesize *)
module mkWiFiFFTIFFT (DualFFTIFFT#(Bool, TXGlobalCtrl, FFTIFFTSz,TXFPIPrec,TXFPFPrec));
   let wifiFFT <- mkDualFFTIFFTRR;  
   return wifiFFT;
endmodule
