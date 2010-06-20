#include "util.h"

#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include <errno.h>

#include <gsl/gsl_randist.h>
#include <gsl/gsl_rng.h>

void model_init()
{
    gsl_rng_env_setup();
}

static gsl_rng *rnd()
{
  static gsl_rng *r = NULL;
  if (r == NULL) {
    r = gsl_rng_alloc(gsl_rng_default);
  }
  return r;
}

double rand_double()
{
  return gsl_rng_uniform(rnd());
}

void* copy_state()
{
    return gsl_rng_clone(rnd());
}

void restore_state(void *state)
{
    gsl_rng_memcpy(rnd(), (gsl_rng *) state);
}

void free_state(void *state)
{
    gsl_rng_free((gsl_rng *) state);
}

// From the GNU Scientific Library, src/randist/gauss.c

/* Polar (Box-Mueller) method; See Knuth v2, 3rd ed, p122 */


Complex gaussian()
{
  double x1, x2, r2;

  do
    {
      /* choose x,y in uniform square (-1,-1) to (+1,+1) */

      x1 = -1 + 2 * rand_double();
      x2 = -1 + 2 * rand_double();

      /* see if it is in the unit circle */
      r2 = x1 * x1 + x2 * x2;
    }
  while (r2 > 1.0 || r2 == 0);

  /* Box-Muller transform */
  double y1 = x1 * sqrt (-2.0 * log (r2) / r2);
  double y2 = x2 * sqrt (-2.0 * log (r2) / r2);

  Complex ret = { y1, y2 };
  return ret;
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

int getenvi(const char *str, int d)
{
  int value = 0;
  char* value_str = getenv(str);
  errno = 0;
  if (value_str) {
    value = strtol(value_str, NULL, 10);
  }
  if (!value_str || errno != 0) {
    value = d;
  }
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
  Complex c = gaussian();
  c.rel *= sigma;
  c.img *= sigma;
  return c;
}

Complex add_complex(Complex a, Complex b)
{
  Complex res = {
    rel: a.rel + b.rel,
    img: a.img + b.img
  };
  return res;
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

Complex cmplx(double real, double imag)
{
  Complex ret = { real, imag };
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

