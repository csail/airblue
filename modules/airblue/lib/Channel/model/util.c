#include "util.h"

#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>

double rand_double()
{
  return rand() / (((double) RAND_MAX) + 1.0);
}

// From the GNU Scientific Library, src/randist/gauss.c

/* Polar (Box-Mueller) method; See Knuth v2, 3rd ed, p122 */

double gaussian()
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

double getenvd(const char *str, double d)
{
  double value = 0.0;
  char* value_str = getenv(str);
  if (value_str)
    value = strtod(value_str, NULL);
  if (value == 0)
    value = d;
  return value;
}

unsigned char isset(const char *str)
{
  const char* value = getenv(str);
  return value != NULL && strlen(value) > 0;
}

double get_snr()
{
  return getenvd("ADDNOISE_SNR", DEFAULT_SNR);
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

Complex mult_complex(Complex a, Complex b)
{
  Complex res = {
    rel: a.rel * b.rel - a.img * b.img,
    img: a.rel * b.img + a.img * b.rel
  };
  return res;
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

static short int shorten(double x)
{
  x = (x / 2) * SHRT_MAX;
  if (x > SHRT_MAX) return SHRT_MAX;
  if (x < SHRT_MIN) return SHRT_MIN;
  return (short int) x;
}

unsigned int pack(Complex x)
{
  unsigned short int real = shorten(x.rel);
  unsigned short int imag = shorten(x.img);

  return (real << 16) + imag;
}

Complex unpack(unsigned int bits)
{
  short int r = (bits >> 16) & 0xFFFF;
  short int i = (bits & 0xFFFF);

  double real = r / ((double) SHRT_MAX) * 2.0;
  double imag = i / ((double) SHRT_MAX) * 2.0;

  Complex ret = { real, imag };
  return ret;
}

double abs2(Complex x)
{
  return (x.rel * x.rel) + (x.img * x.img);
}

