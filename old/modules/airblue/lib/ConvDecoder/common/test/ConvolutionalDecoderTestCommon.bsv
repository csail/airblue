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

import ConfigReg::*;
import GetPut::*;
import Vector::*;
import Complex::*;
import FShow::*;
import FIFO::*;
import StmtFSM::*;

// Local includes
`include "asim/provides/soft_connections.bsh"

`include "asim/provides/airblue_types.bsh"
`include "asim/provides/airblue_parameters.bsh"
`include "asim/provides/airblue_common.bsh"
`include "asim/provides/airblue_special_fifos.bsh"
`include "asim/provides/airblue_fft_library.bsh"
`include "asim/provides/airblue_convolutional_encoder.bsh"
`include "asim/provides/airblue_convolutional_decoder_common.bsh"
`include "asim/provides/airblue_mapper.bsh"
`include "asim/provides/airblue_demapper.bsh"
`include "asim/provides/airblue_puncturer.bsh"
`include "asim/provides/airblue_depuncturer.bsh"
`include "asim/provides/airblue_channel.bsh"
`include "asim/provides/airblue_scrambler.bsh"
`include "asim/provides/airblue_descrambler.bsh"

// testing wifi setting
`define isDebug True // uncomment this line to display error

// every packet is of the same size = LCM
function Bit#(12) getNewLength(Rate rate);
   return case (rate)
	     R0: 144;  // (24/12)-1
	     R1: 144;  // (36/12)-1
	     R2: 144;  // (48/12)-1
	     R3: 144;  // (72/12)-1
	     R4: 144;  // (96/12)-1
	     R5: 144; // (144/12)-1
	     R6: 144; // (192/12)-1
	     R7: 144; // (216/12)-1
	  endcase;
endfunction
          
// symbol = no. 12 bits bundle          
function Bit#(12) getSymCnt(Rate rate);
   return case (rate)
	     R0: 2;  // (24/12)
	     R1: 3;  // (36/12)
	     R2: 4;  // (48/12)
	     R3: 6;  // (72/12)
	     R4: 8;  // (96/12)
	     R5: 12; // (144/12)
	     R6: 16; // (192/12)
	     R7: 18; // (216/12)
	  endcase;
endfunction          

// may be an extra field for DL: sendPremable
typedef struct {
   Bool       firstSymbol; 
   Rate       rate;
   Bit#(12)   length; // in terms of no. 12 bits bundle
   Bool       endSimulation;
} TXGlobalCtrl deriving(Eq, Bits);

instance IsEncoderCtrl#(TXGlobalCtrl);
   function Bool isFirstMesg(TXGlobalCtrl ctrl);
      return ctrl.firstSymbol;
   endfunction
endinstance

typedef struct {
   Bool firstSymbol; 
   Rate rate;
   Bit#(12)   length; // in terms of no. 12 bits bundle
   Bool viterbiPushZeros; // viterbi needs to push zeros to clear all data out  
   Bool       endSimulation;
} RXGlobalCtrl deriving(Eq, Bits);

instance FShow#(TXGlobalCtrl);
  function Fmt fshow(TXGlobalCtrl ctrl);
    return $format(" TXGlobalCtrl: firstSymbol: ") + fshow(ctrl.firstSymbol) + $format(" Rate: ") + fshow(ctrl.rate);
  endfunction
endinstance
          
instance FShow#(RXGlobalCtrl);
  function Fmt fshow(RXGlobalCtrl ctrl);
    return $format(" RXGlobalCtrl: firstSymbol: ") + fshow(ctrl.firstSymbol) + $format(" Rate: ") + fshow(ctrl.rate);
  endfunction
endinstance


function TXGlobalCtrl nextCtrl(TXGlobalCtrl ctrl, Rate new_rate, Bit#(12) new_length, Bool endSimulation);
   return TXGlobalCtrl{ firstSymbol: False, rate: new_rate, length: new_length, endSimulation: endSimulation};
endfunction

typedef 12 ScramblerDataSz;    
typedef  7 ScramblerShifterSz;

Bit#(7) magicConstantSeed = 'b1101001;
Bit#(7) scramblerGenPoly = 'b1001000;
Bit#(7) descramblerGenPoly = scramblerGenPoly;
          
typedef ScramblerCtrl#(12,7) TXScramblerCtrl;
typedef TXScramblerCtrl      RXDescramblerCtrl;

typedef struct {
   TXScramblerCtrl  scramblerCtrl;
   TXGlobalCtrl     globalCtrl;
} TXScramblerAndGlobalCtrl deriving(Eq, Bits); 

function TXScramblerCtrl 
   scramblerMapCtrl(TXScramblerAndGlobalCtrl ctrl);
   return ctrl.scramblerCtrl;
endfunction

function TXGlobalCtrl 
   scramblerConvertCtrl(TXScramblerAndGlobalCtrl ctrl);
    return ctrl.globalCtrl;
endfunction

typedef struct {
   RXDescramblerCtrl  descramblerCtrl;
   RXGlobalCtrl       globalCtrl;
} RXDescramblerAndGlobalCtrl deriving(Eq, Bits); 

function RXDescramblerCtrl 
   descramblerMapCtrl(RXDescramblerAndGlobalCtrl ctrl);
   return ctrl.descramblerCtrl;
endfunction
          
function PuncturerCtrl puncturerMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: Half;
	     R1: ThreeFourth;
	     R2: Half;
	     R3: ThreeFourth;
	     R4: Half;
	     R5: ThreeFourth;
	     R6: TwoThird;
	     R7: ThreeFourth;
	  endcase; // case(rate)
endfunction // Bit  

function Bit#(3) p1 (Bit#(4) x);
   return x[2:0];
endfunction // Bit
   
function Bit#(4) p2 (Bit#(6) x);
   return {x[5],x[2:0]};
endfunction // Bit

// not used in WiFi   
function Bit#(6) p3 (Bit#(10) x);
   return 0;
endfunction // Bit

function DepunctData#(4) dp1 (DepunctData#(3) x);
   DepunctData#(4) out_vec = replicate(0);
   out_vec[0] = x[0];
   out_vec[1] = x[1];
   out_vec[2] = x[2];
   return out_vec;
endfunction // Bit
   
function DepunctData#(6) dp2 (DepunctData#(4) x);
   DepunctData#(6) out_vec = replicate(0);
   out_vec[0] = x[0];
   out_vec[1] = x[1];
   out_vec[2] = x[2];
   out_vec[5] = x[3];
   return out_vec;
endfunction // Bit

// not used in wifi   
function DepunctData#(10) dp3 (DepunctData#(6) x);
   DepunctData#(10) out_vec = replicate(0);
   return out_vec;
endfunction // Bit

// used for both interleaver, mapper
function Modulation modulationMapCtrl(TXGlobalCtrl ctrl);
   return case (ctrl.rate)
	     R0: BPSK;
	     R1: BPSK;
	     R2: QPSK;
	     R3: QPSK;
	     R4: QAM_16;
	     R5: QAM_16;
	     R6: QAM_64;
	     R7: QAM_64;
          endcase;
endfunction
          
function ScramblerMesg#(TXScramblerAndGlobalCtrl,ScramblerDataSz)
   makeMesg(Bit#(ScramblerDataSz) bypass,
	    Maybe#(Bit#(ScramblerShifterSz)) seed,
	    Bool firstSymbol,
            Rate rate,
            Bit#(12) length,
            Bool endSimulation,
	    Bit#(ScramblerDataSz) data);
   let sCtrl = TXScramblerCtrl{bypass: bypass,
			       seed: seed};
   let gCtrl = TXGlobalCtrl{firstSymbol: firstSymbol,
                            length: length,
			    rate: rate,
                            endSimulation: endSimulation};
   let ctrl = TXScramblerAndGlobalCtrl{scramblerCtrl: sCtrl,
				       globalCtrl: gCtrl};
   let mesg = Mesg{control:ctrl, data:data};
   return mesg;
endfunction
          
function Bool viterbiMapCtrl(RXGlobalCtrl ctrl);
   return ctrl.viterbiPushZeros;
endfunction          

(* synthesize *)
module mkConvEncoderInstance(ConvEncoder#(TXGlobalCtrl,12,1,24,2));
   Vector#(2,Bit#(7)) gen_polys = newVector();
   gen_polys[0] = 7'b1011011;
   gen_polys[1] = 7'b1111001;
   ConvEncoder#(TXGlobalCtrl,12,1,24,2) conv_encoder;
   conv_encoder <- mkConvEncoder(gen_polys);
   return conv_encoder;
endmodule

(* synthesize *)
module mkPuncturerInstance (Puncturer#(TXGlobalCtrl,24,24,48,48));
   Bit#(6) f1_sz = 0;
   Bit#(4) f2_sz = 0;
   Bit#(2) f3_sz = 0;
   
   Puncturer#(TXGlobalCtrl,24,24,48,48) puncturer;
   puncturer <- mkPuncturer(puncturerMapCtrl,
			    parFunc(f1_sz,p1),
			    parFunc(f2_sz,p2),
			    parFunc(f3_sz,p3));
   return puncturer;
endmodule

(* synthesize *)
module mkDepuncturerInstance (Depuncturer#(TXGlobalCtrl,24,24,48,48));
   function DepunctData#(24) dpp1(DepunctData#(18) x);
      return parDepunctFunc(dp1,x);
   endfunction
   
   function DepunctData#(24) dpp2(DepunctData#(16) x);
      return parDepunctFunc(dp2,x);
   endfunction
   
   function DepunctData#(20) dpp3(DepunctData#(12) x);
      return parDepunctFunc(dp3,x);
   endfunction
   
   Depuncturer#(TXGlobalCtrl,24,24,48,48) depuncturer;
   depuncturer <- mkDepuncturer(puncturerMapCtrl,dpp1,dpp2,dpp3);
   return depuncturer;
endmodule

(* synthesize *)
module mkMapperInstance (Mapper#(TXGlobalCtrl,24,48,2,14));
   Mapper#(TXGlobalCtrl,24,48,2,14) mapper;
   mapper <- mkMapper(modulationMapCtrl,True);
   return mapper;
endmodule

(* synthesize *)
module mkDemapperInstance (Demapper#(TXGlobalCtrl,48,24,2,14,ViterbiMetric));
   Demapper#(TXGlobalCtrl,48,24,2,14,ViterbiMetric) demapper;
   demapper <- mkDemapper(modulationMapCtrl,True);
   return demapper;
endmodule

(*synthesize*) 
module mkFFTInstance (FFT#(TXGlobalCtrl,64,2,14));
  FFT#(TXGlobalCtrl,64,2,14) fft <- mkFFT;
  return fft;
endmodule

(*synthesize*) 
module mkIFFTInstance (IFFT#(TXGlobalCtrl,64,2,14));
  IFFT#(TXGlobalCtrl,64,2,14) ifft <- mkIFFT;
  return ifft;
endmodule
          
(* synthesize *)
module mkScramblerInstance
   (Scrambler#(TXScramblerAndGlobalCtrl,TXGlobalCtrl,
	       ScramblerDataSz,ScramblerDataSz));
   Scrambler#(TXScramblerAndGlobalCtrl,TXGlobalCtrl,
	      ScramblerDataSz,ScramblerDataSz) block;
   block <- mkScrambler(scramblerMapCtrl,
			scramblerConvertCtrl,
			scramblerGenPoly);
   return block;
endmodule

(* synthesize *)
module mkDescramblerInstance
   (Descrambler#(RXDescramblerAndGlobalCtrl,
		 12,12));
   Descrambler#(RXDescramblerAndGlobalCtrl,
		12,12) block;
   block <- mkDescrambler(descramblerMapCtrl,
			  descramblerGenPoly);
   return block;
endmodule           

