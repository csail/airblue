
#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/airblue_environment.h"
#include "asim/provides/clocks_device.h"
#include "asim/provides/clocks_device.h"
#include "asim/provides/airblue_phy_packet_check.h"

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

  UINT8 packet[] = {0x8,  0x2,  0x3c,  0x0,  0x0,  0x26,  0x8,  0xe3,  0xdd,  0x49,  0x0,  0x18,  0x39,  0x74,  0xce,  0xa6,  0x0,  0x18,  0x39,  0x74,  0xce,  0xa4,  0x10,  0x2f,  0xaa,  0xaa,  0x3,  0x0,  0x0,  0x0,  0x8,  0x0,  0x45,  0x0,  0x0,  0x28,  0x0,  0x0,  0x40,  0x0,  0x2e,  0x6,  0x9c,  0x1f,  0xad,  0xef,  0x41,  0x14,  0xc0,  0xa8,  0x1,  0x5,  0x1,  0xbb,  0xbf,  0x76,  0x1,  0x4e,  0x6c,  0x82,  0x0,  0x0,  0x0,  0x0,  0x50,  0x4,  0x0,  0x0,  0xd0,  0x2d,  0x0,  0x0,  0x70,  0x26,  0x60,  0x1d,  };

  // need to send down a packet 
  for(int i = 0; i < sizeof(packet)/sizeof(UINT8); i++) {
    packetCheckStub->SetExpectedByte(i,packet[i]);
  }
                          
  printf("Enabling packet generation\n");
  while(1){
     PrintPacketCheckStats(packetCheckStub);  
     sleep(3);
  }

}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
