#ifndef _CHANNEL_
#define _CHANNEL_

#include "util.h"

class channel
{
  private:
    bool enable_awgn;
    bool enable_cfo;
    bool enable_fading;

    double gain;
    double snr;
    double freq_offset;

    int cycle;

  public:
    channel();
    ~channel();

    Complex apply(Complex data);
};

#endif
