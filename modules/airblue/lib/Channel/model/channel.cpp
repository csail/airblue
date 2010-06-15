#include <strings.h>
#include <math.h>

#include "channel.h"
#include "util.h"

channel::channel() :
    cycle(0)
{
  for (int i = 0; i < FIR_TAP; i++) {
    history.push_front(cmplx(0,0));
    fir[i] = cmplx(0,0);
  }
  fir[0] = cmplx(0.4322, 0.6732);
  fir[1] = cmplx(0.4388, 0.2397);
  fir[2] = cmplx(-0.2970, 0.0423);

  enable_awgn = isset("ADDNOISE_SNR");
  enable_cfo = isset("CHANNEL_CFO");
  enable_fading = isset("JAKES_DOPPLER");
  enable_multipath = isset("CHANNEL_MULTIPATH");
  enable_threads = isset("CHANNEL_THREADS");

  snr = getenvd("ADDNOISE_SNR", 0.0);
  freq_offset = getenvd("CHANNEL_CFO", 0.0);
  gain = getenvd("CHANNEL_GAIN", 1.0);
  sigma = compute_sigma(snr) / sqrt(2);
}

channel::~channel()
{
}

Complex
channel::apply(Complex signal)
{
#ifdef NOISE_ONLY
  Complex noise = gaussian_fast();
  signal.rel += noise.rel * sigma;
  signal.img += noise.img * sigma;
  return signal;
#else
  if (enable_cfo) {
    signal = cfo(signal, freq_offset, cycle);
  }

  if (enable_multipath) {
    history.push_front(signal);
    history.pop_back();

    signal = cmplx(0,0);
    for (int i = 0; i < FIR_TAP; i++) {
      signal = add_complex(signal, mult_complex(history[i], fir[i]));
    }
  }

  if (enable_fading) {
    signal = rayleigh_channel(signal, cycle);
  }

  if (enable_awgn) {
    if (enable_threads) {
        Complex noise = gaussian_fast();
        signal.rel += noise.rel * sigma;
        signal.img += noise.img * sigma;
    } else {
        signal = add_complex_noise(signal, sigma);
    }
  }

  signal.rel *= gain;
  signal.img *= gain;

  ++cycle;

  return signal;
#endif
}
