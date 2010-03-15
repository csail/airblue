#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>

//Noise variance
#define DEFAULT_SNR 30 // signal to noise ratio
#define PI (4*atan2(1,1))
//#define DELTA_F 100000
#define TIME_STEP 5e-8

#define SIGNAL_POWER 0.0125

// frequency offset (in Hz)
double delta_f = 0;
double dc_offset_real = 0; // (0 <= thisValue < 32768)
double dc_offset_imag = 0; // (0 <= thisValue < 32768)

typedef struct {
  double rel;
  double img;
} Complex;

double rand_double()
{
  return rand() / (((double) RAND_MAX) + 1.0);
}

// From the GNU Scientific Library, src/randist/gauss.c

/* Polar (Box-Mueller) method; See Knuth v2, 3rd ed, p122 */

double gaussian ()
{
  double x, y, r2;

  do
    {
      /* choose x,y in uniform square (-1,-1) to (+1,+1) */

      x = -1 + 2 * rand_double();
      y = -1 + 2 * rand_double();

      /* see if it is in the unit circle */
      r2 = x * x + y * y;
    }
  while (r2 > 1.0 || r2 == 0);

  /* Box-Muller transform */
  return y * sqrt (-2.0 * log (r2) / r2);
}

double get_snr()
{
  static double snr = 0.0;
  if (snr == 0.0) {
    char* snr_str = getenv("ADDNOISE_SNR");
    if (snr_str)
      snr = strtod(snr_str, NULL);
    if (snr == 0)
      snr = DEFAULT_SNR;
  }
  return snr;
}

/* Computes the standard deviation from SNR */
double compute_sigma(double snr)
{
  static double sigma = 0.0;
  if (sigma == 0.0) {
    // variance is: SIGNAL_POWER * pow(10, snr * -0.1)
    // sigma/std dev is: sqrt(variance)
    sigma =  sqrt(SIGNAL_POWER) * pow(10, snr * -0.05);
    printf("sigma: %lf snr: %lf\n", sigma, snr);
  }
  return sigma;
}

Complex gaussian_complex(double sigma)
{
  double mag = sigma * gaussian();
  double rot = rand_double() * PI;

  double rel = mag * cos(rot);
  double img = mag * sin(rot);

  Complex ret = { rel, img };
  return ret;
}

Complex add_complex_noise(Complex signal, double sigma)
{
  Complex noise = gaussian_complex(sigma);
  signal.rel += noise.rel;
  signal.img += noise.img;
  return signal;
}

Complex rotate_complex(Complex signal, double rot)
{
  double rot_real = cos(2 * PI * rot);
  double rot_imag = sin(2 * PI * rot);
  double rel = rot_real * signal.rel - rot_imag * signal.img;
  double img = rot_real * signal.img + rot_imag * signal.rel;

  Complex ret = { rel, img };
  return ret;
}

Complex cmplx(short int real, short int imag)
{
  double real_d = real / ((double) SHRT_MAX) * 2.0;
  double imag_d = imag / ((double) SHRT_MAX) * 2.0;

  Complex ret = { real_d, imag_d };
  return ret;
}

short int shorten(double x)
{
  x = (x / 2) * SHRT_MAX;
  if (x > SHRT_MAX) return SHRT_MAX;
  if (x < SHRT_MIN) return SHRT_MIN;
  return (short int) x;
}

unsigned int pack(Complex x)
{
  short int real = shorten(x.rel);
  short int imag = shorten(x.img);

  unsigned int r = ((unsigned int)real)%(1<<16);
  unsigned int i = ((unsigned int)imag)<<16;

  return r + i;
}

double abs2(Complex x)
{
  return (x.rel * x.rel) + (x.img * x.img);
}

void dbg(Complex signal, Complex noisy)
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

int addNoise(short int real, short int imag, int rot, int res)
{
  static Complex last;

  Complex signal = cmplx(real, imag);

  // rotate
  double delta_rot = rot * rand_double() * 200000 * TIME_STEP;
  Complex rotated = rotate_complex(signal, delta_rot);

  // add noise
  double sigma = compute_sigma(get_snr());
  Complex noisy = add_complex_noise(rotated, sigma);

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
