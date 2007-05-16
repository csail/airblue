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










