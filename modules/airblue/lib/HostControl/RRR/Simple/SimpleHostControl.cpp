#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>

#include "asim/rrr/service_ids.h"
#include "SimpleHostControl.h"
#include "check_ber.h"
#include "asim/provides/airblue_host_control.h"

using namespace std;


// ===== service instantiation =====
SIMPLEHOSTCONTROLRRR_SERVER_CLASS SIMPLEHOSTCONTROLRRR_SERVER_CLASS::instance;

// constructor
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::SIMPLEHOSTCONTROLRRR_SERVER_CLASS()
{
    serverStub = new SIMPLEHOSTCONTROLRRR_SERVER_STUB_CLASS(this);
}

// destructor
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::~SIMPLEHOSTCONTROLRRR_SERVER_CLASS()
{
    Cleanup();
}

// init
void
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::Init(
    PLATFORMS_MODULE p)
{
    parent = p;
}

// uninit
void
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
}

// cleanup
void
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::Cleanup()
{
    delete serverStub;
}

// poll
bool
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::Poll()
{
  return false;
}

//
// RRR service methods
//

// F2HTwoWayMsg
UINT32
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::GetRate(UINT32 dummy)
{
   return get_rate();
}

// F2HTwoWayMsg
UINT32
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::GetFinishCycles(UINT32 dummy)
{
   return get_finish_cycles();
}

// F2HTwoWayMsg
UINT32
SIMPLEHOSTCONTROLRRR_SERVER_CLASS::CheckBER(UINT32 errors, UINT32 total)
{
   return check_ber(errors, total);
}
