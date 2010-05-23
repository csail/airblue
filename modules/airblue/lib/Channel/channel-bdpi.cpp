#include "channel.h"

static channel ch;

extern "C" {

unsigned int
channel_bdpi(unsigned int data)
{
  Complex signal = unpack(data);
  signal = ch.apply(signal);
  return pack(signal);
}

}
