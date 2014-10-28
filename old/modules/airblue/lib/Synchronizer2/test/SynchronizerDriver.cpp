#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>

#include "asim/rrr/service_ids.h"
#include "SynchronizerDriver.h"

using namespace std;

void init_synchronizer_data();
bool get_next_sample(Complex *);


// ===== service instantiation =====
SYNCHRONIZERDRIVER_SERVER_CLASS SYNCHRONIZERDRIVER_SERVER_CLASS::instance;

// constructor
SYNCHRONIZERDRIVER_SERVER_CLASS::SYNCHRONIZERDRIVER_SERVER_CLASS() :
        sendCounter(0), recvCounter(0), packetCounter(0)
{
    serverStub = new SYNCHRONIZERDRIVER_SERVER_STUB_CLASS(this);
    clientStub = new SYNCHRONIZERDRIVER_CLIENT_STUB_CLASS(NULL);
}

// destructor
SYNCHRONIZERDRIVER_SERVER_CLASS::~SYNCHRONIZERDRIVER_SERVER_CLASS()
{
    Cleanup();
}

// init
void
SYNCHRONIZERDRIVER_SERVER_CLASS::Init(
    PLATFORMS_MODULE p)
{
    parent = p;
    init_synchronizer_data();
}

// uninit
void
SYNCHRONIZERDRIVER_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
}

// cleanup
void
SYNCHRONIZERDRIVER_SERVER_CLASS::Cleanup()
{
    delete serverStub;
    delete clientStub;
}

static UINT16 pack10(double x)
{
  short int v = (short int) (x * 512);
  return v & 0x3FF;
}

UINT64
SYNCHRONIZERDRIVER_SERVER_CLASS::GetSamples3()
{
  UINT64 value = 0;

  for (int i = 0; i < 3; i++) {
    Complex data;
    bool sync = get_next_sample(&data);

    data = ch.apply(data);

    if (sync) {
      expected.push_back(sendCounter);
    }

    UINT64 packed = (pack10(data.rel) << 10) | pack10(data.img);
    value |= (packed << (20 * i));

    sendCounter++;
  }

  return value;
}

// poll
bool
SYNCHRONIZERDRIVER_SERVER_CLASS::Poll()
{
  while (sendCounter - recvCounter <= 1000) {
    //printf("sending sendCounter=%lu recvCounter=%lu\n", sendCounter, recvCounter);
    UINT64 v1 = GetSamples3();
    UINT64 v2 = GetSamples3();

    clientStub->SynchronizerIn6(v1, v2);
  }

  if (packetCounter >= 1000) {
     printf("misses = %u success=%u false positives=%u\n", misses,
            success, falsePositives);

     if (misses == 0 && falsePositives == 0 && success == packetCounter) {
         printf("PASS\n");
     }

     exit(0);
  }

  return true;
}

//
// RRR service methods
//

void
SYNCHRONIZERDRIVER_SERVER_CLASS::SynchronizerOut6(UINT8 syncs)
{
  //printf("received sendCounter=%lu recvCounter=%lu\n", sendCounter, recvCounter);
  unsigned int mask = 0x1;
  for (int i = 0; i < 6; i++) {
    bool sync = (syncs & mask) != 0;
    bool should = false;

    if (expected.size() > 0) {
      // packet starts 320 after preamble
      UINT64 packet_start = expected[0] + 320;

      should = (recvCounter == packet_start);
      if (recvCounter >= packet_start) {
        expected.pop_front();
        packetCounter++;
      }
    }

    if (sync && should) {
      //printf("successfully synchronized at %lu\n", recvCounter);
      success++;
    }
    if (sync && !should) {
      //printf("false positive at %lu\n", recvCounter);
      falsePositives++;
    }
    if (!sync && should) {
      //printf("miss at %lu\n", recvCounter);
      misses++;
    }

    ++recvCounter;
    mask = mask << 1;
  }
}
