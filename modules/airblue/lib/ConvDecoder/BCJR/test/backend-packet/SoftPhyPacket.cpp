#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>
#include <math.h>

#include "asim/rrr/service_ids.h"
#include "SoftPhyPacket.h"
using namespace std;


// ===== service instantiation =====
SOFT_PHY_PACKET_RRR_SERVER_CLASS SOFT_PHY_PACKET_RRR_SERVER_CLASS::instance;

// constructor
SOFT_PHY_PACKET_RRR_SERVER_CLASS::SOFT_PHY_PACKET_RRR_SERVER_CLASS()
{
    serverStub = new SOFT_PHY_PACKET_RRR_SERVER_STUB_CLASS(this);
}

// destructor
SOFT_PHY_PACKET_RRR_SERVER_CLASS::~SOFT_PHY_PACKET_RRR_SERVER_CLASS()
{
    Cleanup();
}

// init
void
SOFT_PHY_PACKET_RRR_SERVER_CLASS::Init(
    PLATFORMS_MODULE p)
{
    parent = p;
}

// uninit
void
SOFT_PHY_PACKET_RRR_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
}

// cleanup
void
SOFT_PHY_PACKET_RRR_SERVER_CLASS::Cleanup()
{
    delete serverStub;
}

// poll
bool
SOFT_PHY_PACKET_RRR_SERVER_CLASS::Poll()
{
  return false;
}

//
// RRR service methods
//


// F2HTwoWayMsg
UINT32
SOFT_PHY_PACKET_RRR_SERVER_CLASS::SendPacket(INT32 predicted_ber_fp, UINT32 errors, UINT32 total)
{
  double actual_ber = errors / ((double) total);
  double actual_ber_lg = log(actual_ber) / log(2.0);

  double predicted_ber = predicted_ber_fp / (65536.0);

  printf("Packet predicted: 2^%lf actual: 2^%lf errors:%u bits:%u\n", predicted_ber, actual_ber_lg, errors, total);
  fflush(stdout);
  return 0;
}
