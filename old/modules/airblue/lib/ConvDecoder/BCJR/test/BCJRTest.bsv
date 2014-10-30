//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2009 Kermin Fleming, kfleming@mit.edu 
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

import GetPut::*;
import Vector::*;

// import Controls::*;
// import DataTypes::*;
// import Interfaces::*;
// import BCJR::*;
// import ConvolutionalDecoderTest::*;

// Local includes
`include "asim/provides/soft_connections.bsh"
import AirblueTypes::*;
`include "asim/provides/airblue_convolutional_decoder.bsh"
`include "asim/provides/airblue_convolutional_decoder_test.bsh"
`include "asim/provides/airblue_convolutional_decoder_test_common.bsh"

// testing wifi setting
//`define isDebug True // uncomment this line to display error


module [CONNECTED_MODULE] mkHWOnlyApplication (Empty);
   let bcjrTest <- mkConvolutionalDecoderTest();
endmodule
