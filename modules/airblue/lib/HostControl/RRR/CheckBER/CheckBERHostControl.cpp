#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>

#include "asim/rrr/service_ids.h"
#include "CheckBERHostControl.h"
#include "asim/provides/airblue_environment.h"

using namespace std;


// ===== service instantiation =====
CHECKBERHOSTCONTROLRRR_SERVER_CLASS CHECKBERHOSTCONTROLRRR_SERVER_CLASS::instance;

// constructor
CHECKBERHOSTCONTROLRRR_SERVER_CLASS::CHECKBERHOSTCONTROLRRR_SERVER_CLASS()
{
    serverStub = new CHECKBERHOSTCONTROLRRR_SERVER_STUB_CLASS(this);
}

// destructor
CHECKBERHOSTCONTROLRRR_SERVER_CLASS::~CHECKBERHOSTCONTROLRRR_SERVER_CLASS()
{
    Cleanup();
}

// init
void
CHECKBERHOSTCONTROLRRR_SERVER_CLASS::Init(
    PLATFORMS_MODULE p)
{
    parent = p;
}

// uninit
void
CHECKBERHOSTCONTROLRRR_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
}

// cleanup
void
CHECKBERHOSTCONTROLRRR_SERVER_CLASS::Cleanup()
{
    delete serverStub;
}

// poll
bool
CHECKBERHOSTCONTROLRRR_SERVER_CLASS::Poll()
{
  return false;
}

//
// RRR service methods
//

// F2HTwoWayMsg
UINT64
CHECKBERHOSTCONTROLRRR_SERVER_CLASS::CheckBER(UINT64 errors, UINT64 total)
{
   return check_ber(errors, total);
}
