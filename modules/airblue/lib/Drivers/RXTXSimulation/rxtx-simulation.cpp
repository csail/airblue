
#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/airblue_environment.h"
#include "asim/provides/airblue_host_control.h"
#include "asim/dict/AIRBLUE_REGISTER_MAP.h"

using namespace std;
 
// constructor
AIRBLUE_DRIVER_CLASS::AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p) :
    DRIVER_MODULE_CLASS(p)
{
  clientStub = HostControl::Get(p);
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

  clientStub->Write(1,AIRBLUE_REGISTER_MAP_ADDR_RATE,get_rate());
  clientStub->Write(1,AIRBLUE_REGISTER_MAP_ADDR_ENABLE_PACKET_GEN,~0);
  while(clientStub->Read(0,AIRBLUE_REGISTER_MAP_ADDR_PACKETS_RX) < 50){sleep(5);}
  printf("Done waiting for packets\n");

  // get number of bit errors
  ber = clientStub->Read(0,AIRBLUE_REGISTER_MAP_ADDR_BER);

  // TODO: get total number of bits
  int total = 0;

  result = check_ber(ber, total);
  if(result) {
    printf("Test PASSed, ber was %d",ber);
  } else {
    printf("Test FAILED, ber was %d",ber);
  }

}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
