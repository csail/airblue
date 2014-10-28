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

import FShow::*;
import Vector::*;

// Local includes
`include "asim/provides/airblue_common.bsh"

//`include <../WiFiFPGA/Macros.bsv>

// Generic OFDM Message
typedef struct{
  ctrl_t control;
  data_t data;
} Mesg#(type ctrl_t, type data_t) deriving (Eq, Bits);

// OFDM symbol
typedef Vector#(n, FPComplex#(i_prec, f_prec)) 
        Symbol#(numeric type n, 
		numeric type i_prec, 
		numeric type f_prec); 

// Viterbi Metric
typedef Bit#(5) ViterbiMetric;
typedef Bit#(12) SoftPhyHints;

typedef Bit#(1) ViterbiHardOutput;
typedef Tuple2#(ViterbiHardOutput,SoftPhyHints) ViterbiSoftOutput;

`ifdef SOFT_PHY_HINTS
typedef ViterbiSoftOutput ViterbiOutput;
`else
typedef ViterbiHardOutput ViterbiOutput;
`endif

typedef Vector#(o_sz,ViterbiMetric)
   DepunctData#(numeric type o_sz);

// Transmitter Mesg Types
typedef Mesg#(ctrl_t, Bit#(n)) 
	ScramblerMesg#(type ctrl_t, 
		       numeric type n);

typedef Mesg#(ctrl_t, Bit#(n)) 
        EncoderMesg#(type ctrl_t, 
		     numeric type n);

typeclass IsEncoderCtrl#(type c);
   function Bool isFirstMesg(c ctrl);
endtypeclass

typedef Mesg#(ctrl_t, Bit#(n)) 
        InterleaverMesg#(type ctrl_t, 
			 numeric type n);

typedef Mesg#(ctrl_t, Bit#(n)) 
        MapperMesg#(type ctrl_t, 
		    numeric type n);

typedef Mesg#(ctrl_t, Symbol#(n,i_prec,f_prec))
        PilotInsertMesg#(type ctrl_t, 
			 numeric type n,
			 numeric type i_prec,
			 numeric type f_prec);

typedef Mesg#(ctrl_t, Symbol#(n,i_prec,f_prec)) 
        IFFTMesg#(type ctrl_t, 
		  numeric type n, 
		  numeric type i_prec, 
		  numeric type f_prec);

typedef Mesg#(ctrl_t, Symbol#(n,i_prec,f_prec))
	CPInsertMesg#(type ctrl_t,
		      numeric type n,
		      numeric type i_prec,
		      numeric type f_prec);

typedef FPComplex#(i_prec,f_prec)
	DACMesg#(numeric type i_prec,
		 numeric type f_prec);	       	   

// Receiver Mesg Types
typedef FPComplex#(i_prec,f_prec)
	SynchronizerMesg#(numeric type i_prec,
			  numeric type f_prec);

typedef Mesg#(SyncCtrl, FPComplex#(i_prec,f_prec))
	UnserializerMesg#(numeric type i_prec,
			  numeric type f_prec);
// Bool = isNewPacket
typedef Mesg#(Bool, Symbol#(n,i_prec,f_prec)) 
        SPMesgFromSync#(numeric type n,
			numeric type i_prec,
			numeric type f_prec);

typedef ctrl_t 
        SPMesgFromRXController#(type ctrl_t); 
		
typedef Mesg#(ctrl_t, Symbol#(n,i_prec,f_prec)) 
        FFTMesg#(type ctrl_t, 
		 numeric type n, 
		 numeric type i_prec, 
		 numeric type f_prec);

typedef Mesg#(ctrl_t, Symbol#(n,i_prec,f_prec)) 
        ChannelEstimatorMesg#(type ctrl_t, 
			      numeric type n, 
			      numeric type i_prec, 
			      numeric type f_prec);

	      
typedef Mesg#(ctrl_t, Symbol#(n, i_prec, f_prec))    
        DemapperMesg#(type ctrl_t, 
		      numeric type n,
		      numeric type i_prec, 
		      numeric type f_prec);

typedef Mesg#(ctrl_t, Vector#(n, decode_t))
	DeinterleaverMesg#(type ctrl_t,
			   numeric type n,
			   type decode_t);

typedef Mesg#(ctrl_t, Vector#(n, decode_t)) 
        DecoderMesg#(type ctrl_t, 
		     numeric type n,
		     type decode_t);			

typedef ScramblerMesg#(ctrl_t, n)                  
        DescramblerMesg#(type ctrl_t, 
			 numeric type n);




instance FShow#(Mesg#(ctrl_t, Vector#(n, decode_t)));
  function Fmt fshow(Mesg#(ctrl_t, Vector#(n, decode_t)) mesg);
    return $format(" Mesg ");// + fshow(mesg.control);// + $format(" vec: ") + fshow(mesg.data);
  endfunction
endinstance
