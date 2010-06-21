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
    bool enable_rotate;
    bool enable_multipath;
    bool enable_threads;

    double gain;
    double snr;
    double sigma; // noise variance
    double freq_offset;

    std::deque<Complex> history;
    Complex fir[FIR_TAP];

    int cycle;

  public:
    channel();
    ~channel();

    Complex apply(Complex data);

    int Cycle() { return cycle; }

    void* copy_state();
    void restore_state(void* state);
    void free_state(void* state);
};

#endif
