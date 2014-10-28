
#include "asim/provides/virtual_platform.h"
#include "asim/rrr/client_stub_CBUSRFRRR.h"
#include "asim/provides/rf_driver.h"
#include "asim/dict/AIRBLUE_RF_REGISTER_MAP.h"

using namespace std;
 
// constructor
RF_DRIVER_CLASS::RF_DRIVER_CLASS(PLATFORMS_MODULE p)
{
  clientStub = new CBUSRFRRR_CLIENT_STUB_CLASS(p);
}

// destructor
RF_DRIVER_CLASS::~RF_DRIVER_CLASS()
{
}

// init
void
RF_DRIVER_CLASS::Init()
{
}

// main
void
RF_DRIVER_CLASS::Main()
{


}

