
#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/airblue_environment.h"

using namespace std;
 
// constructor
AIRBLUE_DRIVER_CLASS::AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p) :
    DRIVER_MODULE_CLASS(p)
{
  packetCheckStub = new PACKETCHECKRRR_CLIENT_STUB_CLASS(p); 
  packetGenStub = new PACKETGENRRR_CLIENT_STUB_CLASS(p); 
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

  packetGenStub->SetRate(get_rate());

  // need to send down a packet 
  for(i = 0

  packetGenStub->SetEnable(~0);
  while(packetCheckStub->GetPacketsRX(0) < 50){sleep(5);}
  printf("Done waiting for packets\n");

  // get number of bit errors
  ber = packetCheckStub->GetBER(0);

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
