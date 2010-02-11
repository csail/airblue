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

//import ProtocolParameters::*;
//import ChannelEstimatorParameters::*;

// Local includes
`include "asim/provides/airblue_parameters.bsh"

// from protocol parameters
typedef CEstInDataSz     CEstInN;     // no. fixedpoints input to channel estimator (should be same as output of FFT)
typedef CEstOutDataSz    CEstOutN;    // no. fixedpoints output from channel estimator (should have pilot and guards removed)
typedef RXFPIPrec        CEstIPrec;   // the integral precision of the fixedpoint
typedef RXFPFPrec        CEstFPrec;   // the fractional precision of the fixedpoint
typedef PilotNo          CEstPNo;     // no. of pilots  
typedef PilotPRBSSz      CEstPSz;     // the mask size of the LFSR to generate the pilot values

// derived types
typedef TLog#(CEstOutN)  CEstOutSz;   // no. bits required for indexing out subcarriers
typedef TLog#(CEstPNo)   CEstPBSz;    // no. bits required for indexing pilots
typedef TSub#(CEstPSz,1) CEstPSzSub1; // LFSR - 1