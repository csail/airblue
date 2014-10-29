//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// Copyright (c) 2014 Quanta Research Cambridge, Inc.
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

import FixedPoint::*;

import AirblueCommon::*;
import AirblueTypes::*;
import ProtocolParameters::*;
import FFTParameters::*;
import FParams::*;

typedef enum {
   FFTRequestPortal, FFTIndicationPortal
   } IfcNames deriving (Bits);

typedef struct {
   Bit#(16) i;
   Bit#(16) f;
   } FX1616 deriving (Bits);

function FixedPoint#(16,16) toFixedPoint(FX1616 v); return FixedPoint { i: v.i, f: v.f }; endfunction

interface FFTRequest;
   method Action putInput(FX1616 rv, FX1616 iv);
endinterface

interface FFTIndication;
   method Action checkOutput(Bit#(32) i, FX1616 rv, FX1616 iv);
   method Action generateFFTValues(Bit#(32) fftSize, Bit#(32) realBitSize, Bit#(32) imagBitSize);
   method Action freeLast();
endinterface
