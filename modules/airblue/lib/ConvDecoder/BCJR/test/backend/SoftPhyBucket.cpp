#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>

#include "asim/rrr/service_ids.h"
#include "SoftPhyBucket.h"
using namespace std;


// ===== service instantiation =====
SOFT_PHY_BUCKET_RRR_SERVER_CLASS SOFT_PHY_BUCKET_RRR_SERVER_CLASS::instance;

// constructor
SOFT_PHY_BUCKET_RRR_SERVER_CLASS::SOFT_PHY_BUCKET_RRR_SERVER_CLASS()
{
    serverStub = new SOFT_PHY_BUCKET_RRR_SERVER_STUB_CLASS(this);
}

// destructor
SOFT_PHY_BUCKET_RRR_SERVER_CLASS::~SOFT_PHY_BUCKET_RRR_SERVER_CLASS()
{
    Cleanup();
}

// init
void
SOFT_PHY_BUCKET_RRR_SERVER_CLASS::Init(
    PLATFORMS_MODULE p)
{
    parent = p;
}

// uninit
void
SOFT_PHY_BUCKET_RRR_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
}

// cleanup
void
SOFT_PHY_BUCKET_RRR_SERVER_CLASS::Cleanup()
{
    delete serverStub;
}

// poll
bool
SOFT_PHY_BUCKET_RRR_SERVER_CLASS::Poll()
{
  return false;
}

//
// RRR service methods
//


// F2HTwoWayMsg
UINT32
SOFT_PHY_BUCKET_RRR_SERVER_CLASS::SendBucket(UINT32 index, UINT64 errors, UINT64 total)
{
  printf("Bucket %d errors %llu total %llu\n", index, errors, total);
  fflush(stdout);
  return index;
}
