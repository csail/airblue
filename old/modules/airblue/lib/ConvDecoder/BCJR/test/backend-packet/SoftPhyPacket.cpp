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
SOFT_PHY_PACKET_RRR_SERVER_CLASS::SOFT_PHY_PACKET_RRR_SERVER_CLASS() :
    ber_sum(0), bits(0)
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

void
SOFT_PHY_PACKET_RRR_SERVER_CLASS::SendHints(UINT32 hints_1, UINT32 hints_2, UINT32 hints_3, UINT8 rate, UINT8 last)
{
    //printf("hints: ");
    UINT32 hints[3] = { hints_1, hints_2, hints_3 };
    for (int j = 0; j < 3; j++) {
        UINT32 shift = 0;
        for (int i = 0; i < 4; i++) {
            UINT8 hint = (hints[j] >> shift) & 0xFF;
            //printf("%2hhu ", hint);

            ber_sum += get_ber(hint, rate);
            bits++;

            shift = shift + 8;
        }
    }
    //printf("\n");


    if (last) {
        double avg_ber = ber_sum / bits;
        printf("Packet sw prediction: %lf 2^%lf\n", avg_ber, log(avg_ber) / log(2.0));
        fflush(stdout);

        bits = 0;
        ber_sum = 0.0;
    }
}
