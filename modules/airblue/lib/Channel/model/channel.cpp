#include "channel.h"
#include "util.h"

channel::channel() :
    cycle(0)
{
  enable_awgn = isset("ADDNOISE_SNR");
  enable_cfo = isset("CHANNEL_CFO");
  enable_fading = isset("JAKES_DOPPLER");

  snr = getenvd("ADDNOISE_SNR", 0.0);
  freq_offset = getenvd("CHANNEL_CFO", 0.0);
  gain = getenvd("CHANNEL_GAIN", 1.0);
}

channel::~channel()
{
}

Complex
channel::apply(Complex signal)
{
  if (enable_cfo) {
    signal = cfo(signal, freq_offset, cycle);
  }

  if (enable_fading) {
    signal = rayleigh_channel(signal, cycle);
  }

  if (enable_awgn) {
    signal = awgn(signal, snr);
  }

  signal.rel *= gain;
  signal.img *= gain;

  ++cycle;

  return signal;
}
