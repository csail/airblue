#include "util.h"

#include <math.h>

// 50 nanosecond sample time
static const double sample_time = 5.0e-8;

Complex cfo(Complex signal, double freq_offset, int cycle)
{
   // angle in radians
  double angle = freq_offset * (sample_time * 1000 * 2 * PI) * cycle;

  Complex rot = {
     rel: cos(angle),
     img: sin(angle)
  };

  // rotate signal by angle
  return mult_complex(signal, rot);
}

int cfo_bdpi(unsigned int data, int cycle)
{
  Complex signal = unpack(data);

  // frequency offset in kilohertz
  double freq_offset = getenvd("CHANNEL_CFO", 0.0);

  Complex res = cfo(signal, freq_offset, cycle);

  return pack(res);
}
