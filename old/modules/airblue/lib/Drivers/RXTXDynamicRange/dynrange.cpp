
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
  loopbackStub = new LOOPBACKRRR_CLIENT_STUB_CLASS(p); 
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

  // We probably want more hooks at some point.
  //  UINT8 packet[] = {0x8,  0x2,  0x3c};

  UINT8 packet[] = {0x8,  0x2,  0x3c,  0x0,  0x0,  0x26,  0x8,  0xe3,  0xdd,  0x49,  0x0,  0x18,  0x39,  0x74,  0xce,  0xa6,  0x0,  0x18,  0x39,  0x74,  0xce,  0xa4,  0x10,  0x2f,  0xaa,  0xaa,  0x3,  0x0,  0x0,  0x0,  0x8,  0x0,  0x45,  0x0,  0x0,  0x28,  0x0,  0x0,  0x40,  0x0,  0x2e,  0x6,  0x9c,  0x1f,  0xad,  0xef,  0x41,  0x14,  0xc0,  0xa8,  0x1,  0x5,  0x1,  0xbb,  0xbf,  0x76,  0x1,  0x4e,  0x6c,  0x82,  0x0,  0x0,  0x0,  0x0,  0x50,  0x4,  0x0,  0x0,  0xd0,  0x2d,  0x0,  0x0,  0x70,  0x26,  0x60,  0x1d,  };

  packetGenStub->SetLength(sizeof(packet)/sizeof(UINT8));
  packetCheckStub->SetExpectedLength(sizeof(packet)/sizeof(UINT8));

  // need to send down a packet 
  for(int i = 0; i < sizeof(packet)/sizeof(UINT8); i++) {
    packetGenStub->SetPacketByte(i,packet[i]);
    packetCheckStub->SetExpectedByte(i,packet[i]);
  }
                          
  // packetGenStub->SetDelay(MODEL_CLOCK_FREQ*1000*10);

  printf("Enabling packet generation\n");
  // Gain is in 16.16

  for(int rate = 0; rate < 4; rate++) {
    packetGenStub->SetRate(rate); 
    for(float factor = 1.0/8; factor < 8.0; factor *= 1.25) {
      sleep(10);
      // Now that we are done sleeping, let's set up the next test
      int basePackets = packetCheckStub->GetPacketsRX(0);
      int baseBER     = packetCheckStub->GetBER(0);
      int fixedPtScale = (int)(factor*(1<<16));
      int packetsLast = basePackets;
     
      printf("Setting scale factor to %f, %d\n", factor, fixedPtScale);
      loopbackStub->SetScale(fixedPtScale);     
      packetGenStub->SetEnable(~0);
 
      while(packetCheckStub->GetPacketsRX(0) < basePackets + 50){

        printf("Check has received %d packets\n", packetCheckStub->GetPacketsRX(0));
        sleep(10);
        // if we got no packets, bail
        if(basePackets == packetCheckStub->GetPacketsRX(0)) {
          break;
	}
      }

      packetGenStub->SetEnable(0);

      sleep(3); // For the pipeline to clear
      int  packets = packetCheckStub->GetPacketsRX(0);
      int  ber = packetCheckStub->GetBER(0);
      printf("BERBase:%d:BER:%d:Delta:%d\n", baseBER, ber, (ber - baseBER));
      printf("PacketsBase:%d:Packets:%d:Delta:%d\n", basePackets, packets, (packets - basePackets));
      if(packets != basePackets) {
        float actualBER = (ber - baseBER)/((float)(packets - basePackets))/(8*sizeof(packet));
        printf("Rate:%d:Scale:%d:BER:%f:Packets:%d\n", rate, fixedPtScale, actualBER,(packets - basePackets));
      } else {
        printf("Rate:%d:Scale:%d:BER:1.0:Packets:(No packets)\n", rate, fixedPtScale);
      }
    }
  }

}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
