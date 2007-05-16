import DataTypes::*;
import Interfaces::*;
import Connectable::*;

import FIFOF::*;

import NewSynchronizer::*;
import FixedPoint::*;
import Complex::*;
import Preambles::*;
import Unserializer::*;
import SynchronizerLibrary::*;
import Vector::*;
import RegFile::*;
import FFTIFFT::*;
import Detector::*;
import Viterbi80211::*;
import RX_Controller::*;
import Descrambler::*;



(* synthesize *)
module mkWifiTransceiver(Transceiver);
  Synchronizer#(1,15) synchronizer <- mkWifiSynchronizer();
  FftIfft fftifft <- ;
  serializerUnserializer <- mkSerializerUnserializer();

  receiver <- mkReceiver(synchronizer, controller.rx, fft.rx);
  transmitter <- mkTransmitter(, controller.tx, fft.tx);

  return receiver, transmitter;
end module;

(* synthesize *)
module mkWifiReceiver(Receiver);
  protocolParams = mkProtocolParams(64, ...);
  Synchronizer#(1,15) synchronizer <- mkWifiSynchronizer();
  controller <- mkWifiController();
  mapper <- mkMapper(wifiController);
  fft <- mkFFTIFFT(64);
  channelEstimator <- mkChannelEstimator(protocolParams, wifiChannelEstimatorControlDemux);
  demapper <- mkDemapper(wifiDemapperControlDemux);
  deinterleaver <- mkDeinterleaver(wifiDeinterleaverControlDemux);
  decoder <- mkWifiDecoder(wifiDecoderControlDemux);
  descrambler <- mkDescrambler(wifiDescramblerControlDemux);

  receiver <- mkReceiver(synchronizer, controller, mapper);
  return receiver;
end module;

(* synthesize *)
module mkWimaxReceiver(Receiver);
  Synchronizer#(1,15) synchronizer <- mkWimaxSynchronizer();
  controller <- mkWimaxController();
  Mapper#() mapper <- mkMapper(wimaxMapperControlDemux);
  fft <- mkFFTIFFT(256);
  channelEstimator <- mkChannelEstimator(wimaxChannelEstimatorControlDemux);
  demapper <- mkDemapper(wimaxDemapperControlDemux);
  deinterleaver <- mkDeinterleaver(wimaxDeinterleaverControlDemux);
  decoder <- mkWimaxDecoder(wimaxDecoderControlDemux);
  descrambler <- mkDescrambler(wimaxDescramblerControlDemux);

  receiver <- mkReceiver(synchronizer, controller, fft, channelEstimator, demapper, deinterleaver, decoder, descrambler);

  return receiver;
end module;

(* synthesize *)
module mkWifiTransceiver(Transceiver);
  Synchronizer#(1,15) synchronizer <- mkWifiSynchronizer();

  SharedFFT#(64) sharedFFT <- mkSharedFFT();
  Mapper#() mapper <- mkMapper(wifiMapperController);

  receiver <- mkReceiver(synchronizer, controller, sharedFFT.rx);
  transmitter <- mkTransmitter(synchronizer, controller, sharedFFT.tx );
  interface rx = receiver;
  interface tx = transmitter;
end module;

module mkReceiver#(Synchronizer#(a,b) synchronizer,

	)(Receiver);
   
   mkConnection(synchronizer.out, controller.in);
   mkConnection(controller.out, fft.in);
   mkConnection(fft.out, channelEstimator.in);
   mkConnection(channelEstimator.out, demapper.in);
   mkConnection(demapper.out, deinterleaver.in);
   mkConnection(deinterleaver.out, decoder.in);
   mkConnection(decoder.out, descrambler.in);
   mkConnection(descrambler.toController, controller.fromDescrambler);

   interface Put in = synchronizer.in;
   interface Get out = descrambler.out;
     
endmodule   




