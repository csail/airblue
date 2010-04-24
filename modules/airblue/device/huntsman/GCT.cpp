
#include "asim/provides/virtual_platform.h"
#include "asim/provides/gct_driver.h"


using namespace std;
 
// constructor
GCT_DRIVER_CLASS::GCT_DRIVER_CLASS(PLATFORMS_MODULE p)
{
  clientStub = new SPIMASTERRRR_CLIENT_STUB_CLASS(p);
}

// destructor
GCT_DRIVER_CLASS::~GCT_DRIVER_CLASS()
{
}

// init
void
GCT_DRIVER_CLASS::Init()
{
}

// main
void
GCT_DRIVER_CLASS::Main()
{

}

