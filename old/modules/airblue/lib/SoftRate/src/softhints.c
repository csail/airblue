#include <math.h>

static double ber_sum = 0.0;
static int ber_count = 0;

// Computes the average BER of a packet based on SoftPhy hints.
// Returns the magnitude of the average BER as a power of 1/2. A return value
// x means 2^-x < ber < 2^-x+1.
void update_softphy(unsigned int hint)
{
  double ber = 1.0 / (1.0 + exp((double) hint));
  ber_sum += ber;
  ber_count += 1;
}

double average_ber()
{
  return ber_sum / ber_count;
}

void display_ber()
{
  printf("%0.30lf", average_ber());
}

unsigned int get_softphy_ber()
{
  unsigned int magnitude = 0;
  double avg_ber = ber_sum / ber_count;
  while (avg_ber < 1.0) {
    avg_ber *= 2.0;
    magnitude += 1;
  }

  return magnitude;
}

void reset_softphy()
{
  ber_sum = 0.0;
  ber_count = 0;
}
