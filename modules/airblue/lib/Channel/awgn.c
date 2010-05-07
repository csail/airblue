#include "util.h"

#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>

// frequency offset (in Hz)
double delta_f = 0;
double dc_offset_real = 0; // (0 <= thisValue < 32768)
double dc_offset_imag = 0; // (0 <= thisValue < 32768)

static void dbg(Complex signal, Complex noisy)
{
  static Complex signals[400];
  static Complex noises[400];
  static int idx = 0;
  static int full = 0;

  Complex noise = { noisy.rel - signal.rel, noisy.img - signal.img };

  signals[idx] = signal;
  noises[idx] = noise;

  double signal_power = 0.0;
  double noise_power = 0.0;

  if (full) {
    int i;
    for (i = 0; i < 400; i++) {
      signal_power += abs2(signals[i]);
      noise_power += abs2(noises[i]);
    }

    double snr = signal_power / noise_power;
    double snr_db = 10 * log10(snr);
    printf("AddNoise: SNR = %2.2lf db [400]\n", snr_db);
  }

  // increment index
  idx = (idx + 1) % 400;

  // mark when signals and noise are filled
  full |= (idx == 0);
}

int awgn(unsigned int data)
{
  Complex signal = unpack(data);

  // rotate
  //double delta_rot = rot * rand_double() * 200000 * TIME_STEP;
  //Complex rotated = rotate_complex(signal, delta_rot);

  // add noise
  double sigma = compute_sigma(get_snr());
  Complex noisy = add_complex_noise(signal, sigma);

  // dbg(signal, noisy);

  return pack(noisy);
}

/** Test Case **/

//int main(int argc, char** argv)
//{
//  int i;
//  int L = 100000;
//  double power = 0.0;
//  double noise_power = 0.0;
//
//  for (i = 0; i < L; i++) {
//    Complex signal = gaussian_complex(sqrt(SIGNAL_POWER));
//    power += abs2(signal);
//
//    double sigma = compute_sigma(35);
//    Complex noisy = add_complex_noise(signal, sigma);
//
//    dbg(signal, noisy);
//
//    Complex noise = { noisy.rel - signal.rel, noisy.img - signal.img };
//    noise_power += abs2(noise);
//  }
//
//  double snr = power / noise_power;
//  double snr_db = 10 * log10(snr);
//
//  printf("avg power = %lf\n", (power / L));
//  printf("avg snr = %lf db\n", snr_db);
//}
