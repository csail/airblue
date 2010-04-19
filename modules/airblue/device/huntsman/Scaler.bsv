import ClientServer::*;
import GetPut::*;
import Complex::*;
import FIFO::*;
import CBus::*;
import FixedPoint::*;

// import FIFOUtility::*;
// import CBusUtils::*;
// import Debug::*;

// import FPGAParameters::*;
// import FPComplex::*;
// import DataTypes::*;
// import ProtocolParameters::*;
// import Interfaces::*;

// Local includes
`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/fifo_utils.bsh"
`include "asim/provides/c_bus_utils.bsh"
`include "asim/provides/debug_utils.bsh"

// Do we really need a complex mul scale?  maybe?

module  [ModWithCBus#(AvalonAddressWidth,AvalonDataWidth)] mkScaler#(Integer address) (Scaler#(iprec,fprec))
  provisos ( 
              Add#(a__, TAdd#(iprec, fprec), 32),
              Add#(1, b__, iprec),
              Arith#(FixedPoint::FixedPoint#(iprec, fprec))
           );
  CRAddr#(AvalonAddressWidth,AvalonDataWidth) addrRXScaleFactor = CRAddr{a: fromInteger(address) , o: 0};
  Reg#(FixedPoint#(iprec,fprec)) multiplicativeFactor <- mkCBRegRW(addrRXScaleFactor,fromRational(1,1)); 
  RWire#(SynchronizerMesg#(iprec,fprec)) mullWire <- mkRWire;

  interface Put in;
    method Action put(SynchronizerMesg#(iprec,fprec) data);
      FPComplex#(iprec,fprec) product;
      product.img = multiplicativeFactor * data.img;
      product.rel = multiplicativeFactor * data.rel;
      mullWire.wset(product);
    endmethod    
  endinterface

  interface Get out;
    method ActionValue#(SynchronizerMesg#(iprec,fprec)) get() if(mullWire.wget matches tagged Valid .product);
      return product;
    endmethod
  endinterface
endmodule