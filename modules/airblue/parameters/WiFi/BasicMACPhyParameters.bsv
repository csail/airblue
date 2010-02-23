//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2009 Alfred Man Cheuk Ng, mcn02@mit.edu 
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

//import DataTypes::*;
//import LibraryFunctions::*;
//import ProtocolParameters::*;
//import Scrambler::*;
import Vector::*;
import FShow::*;

// Local includes
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_types.bsh"

typedef 16 PreDataSz;

typedef 6  PostDataSz;

typedef 24 HeaderSz;

typedef Bit#(8) MACAddr; // mac address

typedef Bit#(8) UID; // unique msg ID (for the same src, dest pair)

typedef Maybe#(Bit#(PreDataSz))  PreData;

typedef Maybe#(Bit#(PostDataSz)) PostData;

typedef Bit#(HeaderSz) Header;


typedef struct{
   PhyPacketLength length;
   Rate            rate; 
   Bit#(3)         power;
   Bool            has_trailer; // add trailer (postample + repeated header)
   MACAddr         src_addr;
   MACAddr         dst_addr;
   UID             uid;
} HeaderInfo deriving (Eq, Bits);

typedef struct{
   HeaderInfo header;    // information that should get to header/trailer (non-scrambled and sent at basic rate)
   PreData    pre_data;  // information that sent before data (sent at the same rate as data), if invalid don't send anything
   PostData   post_data; // information that sent after data (sent at the same rate as data), if invalid, don't send anything
} TXVector deriving (Eq, Bits);

typedef struct{
   HeaderInfo header;
   Bool       is_trailer;
} RXVector deriving (Bits, Eq);

typedef union tagged {
   data_t Data;    // correct decode data of data_t
   err_t  Error;  // incorrect decode, error info as err_t 
} Feedback#(type data_t, type err_t) deriving (Bits, Eq);

typedef enum {
   ParityError,
   RateError,
   ZeroFieldError
} RXVectorDecodeError deriving (Bits,Eq);

typedef enum {
  LongSync,
  HeaderDecoded,
  DataComplete,
  Abort
} RXExternalFeedback deriving (Bits,Eq);

function Bool validFeedback(Feedback#(d,e) feedback);
   let res = case (feedback) matches
                tagged Data .x: True;
                default: False;
             endcase;
   return res;
endfunction

function a getDataFromFeedback(a d_res, Feedback#(a,e) feedback);
   let res = case (feedback) matches
                tagged Data .x: x;
                default: d_res;
             endcase;
   return res;
endfunction

function e getErrorFromFeedback(e d_res, Feedback#(a,e) feedback);
   let res = case (feedback) matches
                tagged Error .x: x;
                default: d_res;
             endcase;
   return res;
endfunction
   
// Used by AD.bsv, count the number of samples for preamble/postamble overhead
// depending on whether it has trailer, it will count double if it has
function Bit#(16) getPreambleCount(Bool has_trailer);

   function Integer divCeil(Integer a, Integer b);
      return (a+b-1)/b;
   endfunction
   
   Integer preamble_sz_int = valueOf(SignalStart) + divCeil(valueOf(HeaderSz),bitsPerSymbol(R0))*valueOf(SymbolLen);
   Bit#(16) res = has_trailer ? fromInteger(preamble_sz_int * 2) : fromInteger(preamble_sz_int);
   return res;
endfunction

// used by AD.bsv, count the number of bits going to be sent 
function Bit#(17) getBitLength(PhyPacketLength length);
   return (zeroExtend(length)<<3) + fromInteger(valueOf(PreDataSz)) + fromInteger(valueOf(PostDataSz));
endfunction

function Feedback#(RXVector,RXVectorDecodeError) decodeHeader(Header header);
   
   RXVector vec;
   
   function Maybe#(Rate) getRate(Header header_data);
      return case (header_data[3:0])
		4'b1011: tagged Valid R0;
		4'b1111: tagged Valid R1;
		4'b1010: tagged Valid R2; 
		4'b1110: tagged Valid R3;
		4'b1001: tagged Valid R4;
		4'b1101: tagged Valid R5;
		4'b1000: tagged Valid R6;
		4'b1100: tagged Valid R7;
		default: tagged Invalid;
	     endcase;
   endfunction

   vec.header.rate        = fromMaybe(?,getRate(header));
   vec.header.length      = header[16:5]; 
   vec.header.has_trailer = ?;
   vec.header.power       = ?;
   vec.header.src_addr    = ?;
   vec.header.dst_addr    = ?;
   vec.header.uid         = ?;
   vec.is_trailer         = unpack(header[4:4]);
   let parity_err         = header[17:17] != getParity(header[16:0]); // parity check
   let rate_err           = !isValid(getRate(header));
   let zero_field_err     = header[23:18] != 0;  
   let err                = parity_err ? ParityError : (rate_err ? RateError : ZeroFieldError); 
   let is_err             = parity_err || rate_err || zero_field_err;
   return is_err ? tagged Error err : tagged Data vec;   
endfunction

function Header encoderHeader(HeaderInfo header, Bool is_trailer);
      Bit#(4) translate_rate = case (header.rate)   //somehow checking rate directly doesn't work
				  R0: 4'b1011;
				  R1: 4'b1111;
				  R2: 4'b1010; 
				  R3: 4'b1110;
				  R4: 4'b1001;
				  R5: 4'b1101;
				  R6: 4'b1000;
				  R7: 4'b1100;
			       endcase; // case(r)    
      Bit#(1)  parity = getParity({pack(is_trailer),translate_rate,header.length});
      Bit#(HeaderSz) data = {6'b0,parity,header.length,pack(is_trailer),translate_rate};
      return data;   
endfunction

// this function defines how the scrambler seed is obtained from the predata section (used by RXController)
function Bit#(ScramblerShifterSz) getSeedFromPreData(Bit#(PreDataSz) predata);
   let seed = reverseBits(predata[6:0]); // first 7 bits are original seeds (need to reverse because the MSB of the seedcomes out first)
   let initTup = tuple2(0,seed);
   Vector#(9,Bit#(1)) zero_vec = replicate(0);// get the seed for the next 9 bits (16 total bits for service field i.e. predata)
   let tmp_vec = sscanl(scramble(scramblerGenPoly),initTup,zero_vec);
   match {.dont_care,.new_seeds} = unzip(tmp_vec);
   return last(new_seeds);
endfunction


//Old definitions, used by old MAC
//SHIM in the MAC translates between old and new vectors

instance FShow#(BasicTXVector);
   function Fmt fshow (BasicTXVector vec);
      return $format("TX Vector: Length: ") + fshow(vec.length) + $format(" Rate: ") + fshow(vec.rate);
   endfunction
endinstance

typedef struct{
   PhyPacketLength length;  // data to send in bytes
   Rate            rate;    // data rate
   Bit#(16)        service; // service bits, should be all 0s
   Bit#(3)         power;   // transmit power level (not affecting baseband)
   MACAddr         src_addr;
   MACAddr         dst_addr;	       
   } BasicTXVector deriving (Eq, Bits);

instance FShow#(BasicRXVector);
   function Fmt fshow (BasicRXVector vec);
      return $format("RX Vector: Length: ") + fshow(vec.length) + $format(" Rate: ") + fshow(vec.rate);
   endfunction
endinstance

typedef struct{
   Rate      rate;
   PhyPacketLength length;
   } BasicRXVector deriving (Bits, Eq);
