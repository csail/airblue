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

import GetPut::*;
import Vector::*;

// import Controls::*;
// import CPInsert::*;
// import DataTypes::*;
// import FPComplex::*;
// import Interfaces::*;
// import WiFiPreambles::*;

// Local includes
import AirblueCommon::*;
import AirblueTypes::*;
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_cyclic_prefix_insert.bsh"

typedef Bool WiFiCtrl;

function CPInsertCtrl mapWiFiCPCtrl(WiFiCtrl ctrl);
   return ctrl ? tuple2(SendLong, CP0) : tuple2(SendNone, CP0);
endfunction


(* synthesize *)
module mkWiFiCPInsert(CPInsert#(WiFiCtrl,64,1,15));
   let cpInsert <- mkCPInsert(mapWiFiCPCtrl,
			      getShortPreambles,
			      getLongPreambles);
   return cpInsert;
endmodule

module mkHWOnlyApplication (Empty);
   
   let cpInsert <- mkWiFiCPInsert();
   
endmodule

