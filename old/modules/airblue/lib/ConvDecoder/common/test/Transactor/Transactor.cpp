#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>

#include "asim/rrr/service_ids.h"
#include "Transactor.h"
#include "asim/provides/airblue_transactor.h"

using namespace std;


// ===== service instantiation =====
TRANSACTORRRR_SERVER_CLASS TRANSACTORRRR_SERVER_CLASS::instance;

// constructor
TRANSACTORRRR_SERVER_CLASS::TRANSACTORRRR_SERVER_CLASS()
{
    serverStub = new TRANSACTORRRR_SERVER_STUB_CLASS(this);
}

// destructor
TRANSACTORRRR_SERVER_CLASS::~TRANSACTORRRR_SERVER_CLASS()
{
    Cleanup();
}

// init
void
TRANSACTORRRR_SERVER_CLASS::Init(
    PLATFORMS_MODULE p)
{
    parent = p;
}

// uninit
void
TRANSACTORRRR_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
}

// cleanup
void
TRANSACTORRRR_SERVER_CLASS::Cleanup()
{
    delete serverStub;
}

// poll
bool
TRANSACTORRRR_SERVER_CLASS::Poll()
{
  return false;
}

//
// RRR service methods
//

#define DEFAULT_XACTOR_TYPE 0 // 0 = no clock ctrl
                              // 1 = clock ctrl for both tx and rx (only send and receive every certain cycles)
                              // 2 = clock ctrl for only rx (only require rx to receive data every certain cycles)  

UINT8
TRANSACTORRRR_SERVER_CLASS::GetXactorType(UINT8 dummy)
{
  unsigned char xactor_type = DEFAULT_XACTOR_TYPE;
  char* xactor_type_str = getenv("AIRBLUE_XACTOR_TYPE");
  if (xactor_type_str) {
     xactor_type = (unsigned char) atoi(xactor_type_str);
  }
  return xactor_type;
}

#define DEFAULT_XACTOR_CLK_CTRL 80 // sampling rate (every xx cycles)

UINT32
TRANSACTORRRR_SERVER_CLASS::GetXactorClkCtrl(UINT32 dummy)
{
  unsigned int xactor_clk_ctrl = DEFAULT_XACTOR_CLK_CTRL;
  char* xactor_clk_ctrl_str = getenv("AIRBLUE_XACTOR_CLK_CTRL");
  if (xactor_clk_ctrl_str) {
     xactor_clk_ctrl = (unsigned int) atoi(xactor_clk_ctrl_str);
  }
  return xactor_clk_ctrl;
}
