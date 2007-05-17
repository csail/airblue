import GetPut::*;
import Vector::*;

import ofdm_base::*;

// import Controls::*;
// import FPComplex::*;

// Controls Definitions for Generic OFDM Designs
typedef struct {
    Bit#(n) bypass; // bypass mask, scrambling state still go on
    Maybe#(Bit#(ssz)) seed; // set new seed if valid
} ScramblerCtrl#(numeric type n, numeric type ssz) deriving(Eq, Bits);

typedef struct {
    Bit#(sz) in;    // input size (in bytes)
    Bit#(sz) out;   // output size (in bytes)
} ReedSolomonCtrl#(numeric type sz);

// Modulation Schemes // used as control for mapper, demapper, interleaver and deinterleaver
typedef enum{ 
   BPSK = 1, 
   QPSK = 2, 
   QAM_16 = 4,
   QAM_64 = 8 
} Modulation deriving (Eq, Bits);

// Descrambler Controls
typedef enum{ Bypass, FixRst, DynRst, Norm } DescramblerCtrl deriving (Eq, Bits);

// Puncturer Controls  

typedef enum{
//   Same        = 1,	// control same as last data    
   Half        = 1,     // set to rate 1/2
   TwoThird    = 2,     // set to rate 2/3
   ThreeFourth = 4,     // set to rate 3/4
   FiveSixth   = 8      // set to rate 5/6
} PuncturerCtrl deriving(Eq, Bits);

typedef enum{
   CP0 = 1,     // cp size = 1/4
   CP1 = 2,     // cp size = 1/8
   CP2 = 4,     // cp size = 1/16
   CP3 = 8      // cp size = 1/32
} CPSizeCtrl deriving(Eq, Bits);

typedef enum{
   SendNone = 1, // do not send preamble
   SendBoth = 2, // send both short and long preamble
   SendLong = 4  // send long preamble only
} PreCtrl deriving(Eq, Bits);  

typedef Tuple2#(PreCtrl, CPSizeCtrl) CPInsertCtrl; // first specify addPremable? 

typedef enum{
   PilotRst,  // reset pilot
   PilotNorm  // normal operation
} PilotInsertCtrl deriving (Bits, Eq); 
	     
// not used
typedef struct{
   Bool        isNewPacket;
   CPSizeCtrl  cpSize;
} SyncCtrl deriving (Eq, Bits);

// Data types definition
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
typedef Bit#(3) ViterbiMetric;

typedef Vector#(o_sz,ViterbiMetric)
   DepunctData#(numeric type o_sz);

// Transmitter Mesg Types
typedef Mesg#(ctrl_t, Bit#(n)) 
	ScramblerMesg#(type ctrl_t, 
		       numeric type n);

typedef Mesg#(ctrl_t, Bit#(n)) 
        EncoderMesg#(type ctrl_t, 
		     numeric type n);

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
typedef Encoder#(ctrl_t,i_n,o_n)
	ConvEncoder#(type ctrl_t,
		     numeric type i_n,
		     numeric type o_n);

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
typedef Decoder#(ctrl_t,i_n,ViterbiMetric,o_n,Bit#(1))
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
typedef Scrambler#(ctrl_t,Bit#(0),i_n,o_n)
        Descrambler#(type ctrl_t,
		     numeric type i_n,
		     numeric type o_n);
	   
