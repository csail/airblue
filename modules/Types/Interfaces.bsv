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

import DataTypes::*;
import FPComplex::*;
import GetPut::*;
import Vector::*;

// Local includes
//`include "asim/provides/airblue_common.bsh"

// Generic OFDM Module Interface
interface Block#(type in_t, type out_t);
    interface Put#(in_t) in;
    interface Get#(out_t) out;
endinterface


// Transmitter Modules
// Scrmabler
typedef Block#(ScramblerMesg#(i_ctrl_t,i_n),
	       EncoderMesg#(o_ctrl_t,o_n))
        Scrambler#(type i_ctrl_t,
		   type o_ctrl_t,
		   numeric type i_n,
		   numeric type o_n);
		   
// FEC Encoder		   		   
typedef Block#(EncoderMesg#(ctrl_t,i_n),
	       EncoderMesg#(ctrl_t,o_n))
        Encoder#(type ctrl_t,
		 numeric type i_n,
		 numeric type o_n);

// Reed Solomon Encoder
typedef Encoder#(ctrl_t,i_n,o_n)
        ReedEncoder#(type ctrl_t,
		     numeric type i_n,
		     numeric type o_n);
		     
// Convolutional Encoder		     
typedef Encoder#(ctrlT,inSz,outSz)
	ConvEncoder#(type ctrlT,
                     numeric type inSz,
                     numeric type convInSz,
		     numeric type outSz,
                     numeric type convOutSz);

// Puncturer		     
typedef Encoder#(ctrl_t,i_n,o_n)
        Puncturer#(type ctrl_t,            // ctrl
		   numeric type i_n,       // input size
		   numeric type o_n,       // output size
		   numeric type i_buf_sz,  // input buffer size
		   numeric type o_buf_sz); // output buffer size

// InterleaveBlock (common for Interleaver and Deinterleaver)
typedef Block#(Mesg#(ctrl_t,Vector#(i_n,data_t)),
	       Mesg#(ctrl_t,Vector#(o_n,data_t)))
        InterleaveBlock#(type ctrl_t,
			 numeric type i_n,
			 numeric type o_n,
			 type data_t,
			 numeric type minNcbps);

// Interleaver
typedef Block#(InterleaverMesg#(ctrl_t,i_n),
	       MapperMesg#(ctrl_t,o_n))
	Interleaver#(type ctrl_t,
		     numeric type i_n,
		     numeric type o_n,
		     numeric type minNcbps);

// Mapper
typedef Block#(MapperMesg#(ctrl_t,i_n),
	       PilotInsertMesg#(ctrl_t,n,i_prec,f_prec))
	Mapper#(type ctrl_t,
		numeric type i_n,
		numeric type n,
		numeric type i_prec,
		numeric type f_prec);

// PilotInsert
typedef Block#(PilotInsertMesg#(ctrl_t,i_n,i_prec,f_prec),
	       IFFTMesg#(ctrl_t,o_n,i_prec,f_prec)) 
	PilotInsert#(type ctrl_t,          // ctrl
		     numeric type i_n,     // fft sz - guards/pilots
		     numeric type o_n,     // fft sz
		     numeric type i_prec,  // integer precision
		     numeric type f_prec); // fractional precision

// IFFT
typedef Block#(IFFTMesg#(ctrl_t,n,i_prec,f_prec),
	       CPInsertMesg#(ctrl_t,n,i_prec,f_prec))
	IFFT#(type ctrl_t,
	      numeric type n,
	      numeric type i_prec,
	      numeric type f_prec);

// CPInsert
typedef Block#(CPInsertMesg#(ctrl_t,n,i_prec,f_prec),
	       DACMesg#(i_prec,f_prec))
        CPInsert#(type ctrl_t,          // ctrl
		  numeric type n,       // fft sz
		  numeric type i_prec,  // integer precision
		  numeric type f_prec); // fractional precision

// Transmitter
typedef Block#(ScramblerMesg#(ctrl_t,n),
	       DACMesg#(i_prec,f_prec))
	Transmitter#(type ctrl_t,
		     numeric type n,
		     numeric type i_prec,
		     numeric type f_prec);
//Scaler module 
typedef Block#(SynchronizerMesg#(i_prec,f_prec),
	       SynchronizerMesg#(i_prec,f_prec))
	Scaler#(numeric type i_prec,
		numeric type f_prec);


// Receiver Modules
// Synchronizer
typedef Block#(SynchronizerMesg#(i_prec,f_prec),
	       UnserializerMesg#(i_prec,f_prec))
	Synchronizer#(numeric type i_prec,
		      numeric type f_prec);

// Unserializer
typedef Block#(UnserializerMesg#(i_prec,f_prec),
	       SPMesgFromSync#(n,i_prec,f_prec))
	Unserializer#(numeric type n,
		      numeric type i_prec,
		      numeric type f_prec);

// ReceiverPreFFT
typedef Block#(SynchronizerMesg#(i_prec,f_prec),
	       SPMesgFromSync#(n,i_prec,f_prec))
	ReceiverPreFFT#(numeric type n,
			numeric type i_prec,
			numeric type f_prec);

// FFT		      		      
typedef Block#(FFTMesg#(ctrl_t,n,i_prec,f_prec),
	       ChannelEstimatorMesg#(ctrl_t,n,i_prec,f_prec))
	FFT#(type ctrl_t,
	     numeric type n,
	     numeric type i_prec,
	     numeric type f_prec);

// Channel Estimator
typedef Block#(ChannelEstimatorMesg#(ctrl_t,i_n,i_prec,f_prec),
	       DemapperMesg#(ctrl_t,o_n,i_prec,f_prec))
	ChannelEstimator#(type ctrl_t,
			  numeric type i_n,
			  numeric type o_n,
			  numeric type i_prec,
			  numeric type f_prec);

// Demapper
typedef Block#(DemapperMesg#(ctrl_t,i_n,i_prec,f_prec),
	       DeinterleaverMesg#(ctrl_t,o_n, decode_t))
	Demapper#(type ctrl_t,
		  numeric type i_n,
		  numeric type o_n,
		  numeric type i_prec,
		  numeric type f_prec,
		  type decode_t);

// Deinterleaver
typedef Block#(DeinterleaverMesg#(ctrl_t,i_n,decode_t),
	       DecoderMesg#(ctrl_t,o_n,decode_t))
	Deinterleaver#(type ctrl_t,
		       numeric type i_n,
		       numeric type o_n,
		       type decode_t,
		       numeric type minNcbps);

// Decoder
typedef Block#(DecoderMesg#(ctrl_t,i_n,i_decode_t),
	       DecoderMesg#(ctrl_t,o_n,o_decode_t))
	Decoder#(type ctrl_t,
		 numeric type i_n,
		 type i_decode_t,
		 numeric type o_n,
		 type o_decode_t);
		 
// Depuncturer
typedef Decoder#(ctrl_t,i_n,ViterbiMetric,o_n,ViterbiMetric)
	Depuncturer#(type ctrl_t,
		     numeric type i_n,
		     numeric type o_n,
		     numeric type i_buf_sz,
		     numeric type o_buf_sz);

// Viterbi
typedef Decoder#(ctrl_t,i_n,ViterbiMetric,o_n,ViterbiOutput)
	Viterbi#(type ctrl_t,
		 numeric type i_n,
                 numeric type o_n);

// Reed Solomon Decoder
typedef Decoder#(ctrl_t,i_n,Bit#(1),o_n,Bit#(1))
	ReedDecoder#(type ctrl_t,
		     numeric type i_n,
		     numeric type o_n);

// ReceiverPreDescrambler
typedef Block#(FFTMesg#(ctrl_t,i_n,i_prec,f_prec),
	       DecoderMesg#(ctrl_t,o_n,o_t))
	ReceiverPreDescrambler#(type ctrl_t,
				numeric type i_n,
				numeric type i_prec,
				numeric type f_prec,
				numeric type o_n,
				type o_t);

// Descrambler
typedef Scrambler#(ctrl_t,ctrl_t,i_n,o_n)
        Descrambler#(type ctrl_t,
		     numeric type i_n,
		     numeric type o_n);
	   
		     

