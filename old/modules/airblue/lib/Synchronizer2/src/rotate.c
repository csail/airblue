#include <math.h>
#include <limits.h>
#include <stdio.h>

#define PI M_PI

typedef struct {
  double rel;
  double img;
} Complex;

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

        
unsigned int
rotate(unsigned int d, unsigned int count, int corr_real, int corr_imag)
{
  Complex signal = unpack(d);

  double cr = corr_real / 16384.0;
  double ci = corr_imag / 16384.0;

  double angle = atan2(ci, cr) / 16.0;
  //printf("cr = %lf, ci = %lf, angle = %lf\n", cr, ci, angle);

  signal = rotate_complex(signal, -angle * count / (2 * PI));

  return pack(signal);
}
