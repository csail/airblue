
#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/airblue_environment.h"
#include "asim/rrr/client_stub_CBUSCONTROLRRR.h"
#include "asim/dict/AIRBLUE_REGISTER_MAP.h"

using namespace std;
 
// constructor
AIRBLUE_DRIVER_CLASS::AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p)
{
  clientStub = new CBUSCONTROLRRR_CLIENT_STUB_CLASS(p);
}

// destructor
AIRBLUE_DRIVER_CLASS::~AIRBLUE_DRIVER_CLASS()
{
}

// init
void
AIRBLUE_DRIVER_CLASS::Init()
{
}

// main
void
AIRBLUE_DRIVER_CLASS::Main()
{
  int ber,result;

  clientStub->Write(AIRBLUE_REGISTER_MAP_ADDR_RATE,get_rate());
  clientStub->Write(AIRBLUE_REGISTER_MAP_ADDR_ENABLE_PACKET_GEN,~0);

  printf("Transciever operational\n");
  while(1){}

}

