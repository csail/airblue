import Controls::*;
import FPComplex::*;
import Vector::*;

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



