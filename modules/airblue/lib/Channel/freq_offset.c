#include "util.h"

#include <math.h>

// 50 nanosecond sample time
static const double sample_time = 5.0e-8;

int cfo(unsigned int data, int cycle)
{
  Complex signal = unpack(data);

  // frequency offset in kilohertz
  double freq_offset = getenvd("CHANNEL_CFO", 0.0);

  // angle in radians
  double angle = freq_offset * (sample_time * 1000 * 2 * PI) * cycle;

  Complex rot = {
     rel: cos(angle),
     img: sin(angle)
  };

  // rotate signal by angle
  signal = mult_complex(signal, rot);

  return pack(signal);
}
