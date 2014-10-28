//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

//////////////////////////////////////////////////////////
// Some useful functions for FixedPoint Type
// Author: Alfred Man C Ng 
// Email: mcn02@mit.edu
// Data: 9-29-2006
/////////////////////////////////////////////////////////

// Library imports.

import FIFO::*;
import SpecialFIFOs::*;
import CBus::*; // extendNP and friends

// Project foundation imports.

//`include "awb/provides/librl_bsv_base.bsh"
//`include "awb/provides/librl_bsv_storage.bsh"
//`include "awb/provides/fpga_components.bsh"


import FixedPoint::*;

// take the most significant n bits from the fixedpoint value, result represented in bits
function Bit#(n) fxptGetMSBs(FixedPoint#(ai,af) x)
  provisos (Add#(n, xxA, TAdd#(ai,af)));
            //Bits#(FixedPoint#(ai, af), TAdd#(n, xxA))*/);
      return tpl_1(split(pack(x)));
endfunction // Bit

function Bit#(rf) adjustFraction(Bit#(af) a);
  Bit#(rf) fPart = ?;
  if(valueof(rf) > valueof(af))
    begin
      fPart = zeroExtendNP(a) << (valueof(rf) - valueof(af));
    end
  else
    begin
      fPart = truncateNP(a >> (valueof(af) - valueof(rf)));
    end
  return fPart;
endfunction


function FixedPoint#(ri,rf) fxptSignedAdjust(FixedPoint#(ai,af) a);
  Bit#(ri) iPart = ?;
  Bit#(rf) fPart = adjustFraction(a.f);

  if(valueof(ri) > valueof(ai))
    begin
      iPart = signExtendNP(a.i);
    end
  else
    begin
      iPart = truncateNP(a.i);
    end

  return FixedPoint{i:iPart,f:fPart}; 
endfunction

function FixedPoint#(ri,rf) fxptZeroAdjust(FixedPoint#(ai,af) a);
  Bit#(ri) iPart = ?;
  Bit#(rf) fPart = adjustFraction(a.f);

  if(valueof(ri) > valueof(ai))
    begin
      iPart = zeroExtendNP(a.i);
    end
  else
    begin
      iPart = truncateNP(a.i);
    end

  return FixedPoint{i:iPart,f:fPart};
endfunction





















