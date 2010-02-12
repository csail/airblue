import FixedPoint::*;

//import ProtocolParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"

// Need at least half the floating point precision
// This is needed to scale up large valuse. 
typedef TAdd#(TDiv#(RXFPFPrec,2),RXFPIPrec) ISRIPrec; 
typedef RXFPFPrec ISRFPrec; 

typedef 5 ISRIterations; // number of iteration cycles until result is ready.