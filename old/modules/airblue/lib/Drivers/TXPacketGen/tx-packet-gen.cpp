
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
  sataStub = new SATARRR_CLIENT_STUB_CLASS(p); 
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

  packetGenStub->SetRate(0);
  packetGenStub->SetMaxLength(256);
  packetGenStub->SetMinLength(0);
  packetGenStub->SetEnable(~0);

  while(1){
    sleep(5);
    printf("PacketCheck: Packets Received: %d BER: %d\n", 
           packetCheckStub->GetPacketsRX(0),
           packetCheckStub->GetBER(0)
          );
    printf("RX: %d TX: %d TXIn: %d Errors: %d\n", sataStub->GetRXCount(0), sataStub->GetTXCount(0), sataStub->GetTXCountIn(0), sataStub->GetRXErrors(0));
  }
}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
