#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>

#define SIGNAL_POWER 0.0125

typedef struct {
  double rel;
  double img;
} Complex;


// return a range of [0,1.0)
static double rand_double()
{
  return rand() / (((double) RAND_MAX) + 1.0);
}

static Complex rand_cmplx()
{
   double avg_signal_mag = sqrt(SIGNAL_POWER)/2;
   double rand_rel = rand_double() * avg_signal_mag;
   double rand_img = rand_double() * avg_signal_mag;

   Complex ret = {rand_rel, rand_img};
   return ret;
}

static short int shorten(double x)
{
  x = (x / 2) * SHRT_MAX;
  if (x > SHRT_MAX) return SHRT_MAX;
  if (x < SHRT_MIN) return SHRT_MIN;
  return (short int) x;
}

static unsigned int pack(Complex x)
{
  short int real = shorten(x.rel);
  short int imag = shorten(x.img);

  unsigned int r = ((unsigned int)real)%(1<<16);
  unsigned int i = ((unsigned int)imag)<<16;

  return r + i;
}

int nextRandData()
{
   return pack(rand_cmplx());
}
