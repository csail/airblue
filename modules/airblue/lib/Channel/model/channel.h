#ifndef _CHANNEL_
#define _CHANNEL_

#include <deque>
#include "util.h"

#define FIR_TAP 10

class channel
{
  private:
    bool enable_awgn;
    bool enable_cfo;
    bool enable_fading;
    bool enable_multipath;

    double gain;
    double snr;
    double freq_offset;

    std::deque<Complex> history;
    Complex fir[FIR_TAP];

    int cycle;

  public:
    channel();
    ~channel();

    Complex apply(Complex data);
};

#endif
