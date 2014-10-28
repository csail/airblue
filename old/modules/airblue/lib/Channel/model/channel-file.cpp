#include <strings.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "channel.h"
#include "util.h"

static FILE* file;
static int sample;
double SCALE;

double noise_power = 0;
double signal_power = 0;

extern "C" {

unsigned int
channel_get_sample()
{
  printf("SNR %lf db\n", 10.0 * log(signal_power / noise_power) / log(10.0));
  return sample;
}

}

channel::channel()
{
    if ((file = fopen("noise.bin", "r")) == NULL) {
        printf("error opening noise.bin\n");
        exit(1);
    }

    if (!isset("CHANNEL_SAMPLE")) {
        printf("env var CHANNEL_SAMPLE not set\n");
        exit(1);
    }

    sample = atoi(getenv("CHANNEL_SAMPLE"));
    fseek(file, sample * 16, SEEK_SET);

    SCALE = sqrt(SIGNAL_POWER);
}

channel::~channel()
{
}

Complex
channel::apply(Complex signal)
{
  double values[2];
  if (fread(values, sizeof(double), 2, file) != 2) {
    printf("error reading from noise.bin\n");
    exit(1);
  }

  sample++;

  values[0] *= SCALE;
  values[1] *= SCALE;

  noise_power += (values[0] * values[0]) + (values[1] * values[1]);
  signal_power += signal.rel * signal.rel + signal.img * signal.img;

  signal.rel += values[0];
  signal.img += values[1];

  return signal;
}
