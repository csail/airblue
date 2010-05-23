#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>

#include "channel-rrr.h"
#include "util.h"
#include "asim/rrr/service_ids.h"
#include "asim/provides/connected_application.h"



using namespace std;

// ===== service instantiation =====
CHANNEL_RRR_SERVER_CLASS CHANNEL_RRR_SERVER_CLASS::instance;

// constructor
CHANNEL_RRR_SERVER_CLASS::CHANNEL_RRR_SERVER_CLASS() :
  serverStub(new CHANNEL_RRR_SERVER_STUB_CLASS(this))
  //clientStub(new CHANNEL_RRR_CLIENT_STUB_CLASS(NULL))
{
    fflush(stdout);
}

// destructor
CHANNEL_RRR_SERVER_CLASS::~CHANNEL_RRR_SERVER_CLASS()
{
    Cleanup();
}

// init
void
CHANNEL_RRR_SERVER_CLASS::Init(PLATFORMS_MODULE p)
{
    parent = p;
}

// uninit
void
CHANNEL_RRR_SERVER_CLASS::Uninit()
{
    Cleanup();
}

// cleanup
void
CHANNEL_RRR_SERVER_CLASS::Cleanup()
{
    delete serverStub;
    //delete clientStub;
}


//
// RRR service methods
//

//UINT32
//void
OUT_TYPE_Channel
CHANNEL_RRR_SERVER_CLASS::Channel (
    UINT8 size,
    UINT32 data0, UINT32 data1, UINT32 data2, UINT32 data3, UINT32 data4,
    UINT32 data5, UINT32 data6, UINT32 data7, UINT32 data8, UINT32 data9,
    UINT32 cycle )
{

  UINT32 samples[] = {
    data0, data1, data2, data3, data4,
    data5, data6, data7, data8, data9
  };

  for (int i = 0; i < size; i++) {
    Complex signal = unpack(samples[i]);
    samples[i] = pack(ch.apply(signal));
  }

  OUT_TYPE_Channel out = {
    size,
    samples[0], samples[1], samples[2], samples[3], samples[4],
    samples[5], samples[6], samples[7], samples[8], samples[9]
  };

  return out;
}
