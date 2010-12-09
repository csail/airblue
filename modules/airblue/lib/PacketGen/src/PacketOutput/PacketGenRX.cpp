#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>

#include "asim/rrr/service_ids.h"
#include "asim/provides/airblue_phy_packet_gen.h"

using namespace std;

// ===== service instantiation =====
PACKETCHECKRRR_SERVER_CLASS PACKETCHECKRRR_SERVER_CLASS::instance;

enum {
  HEADER = 0,
  DATA = 1
};

// constructor
PACKETCHECKRRR_SERVER_CLASS::PACKETCHECKRRR_SERVER_CLASS()
{
    // instantiate stub
    printf("PACKETCHECKRRR init called\n");
    outputFile = NULL;
    serverStub = new PACKETCHECKRRR_SERVER_STUB_CLASS(this);
    length = 0;
    dataReceived = 0;
}

// destructor
PACKETCHECKRRR_SERVER_CLASS::~PACKETCHECKRRR_SERVER_CLASS()
{
    Cleanup();
}

// init
void
PACKETCHECKRRR_SERVER_CLASS::Init(
    PLATFORMS_MODULE p)
{
    parent = p;
}

// uninit
void
PACKETCHECKRRR_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
}

// cleanup
void
PACKETCHECKRRR_SERVER_CLASS::Cleanup()
{
    delete serverStub;
}

// poll
bool
PACKETCHECKRRR_SERVER_CLASS::Poll()
{
  return false;
}

// F2HTwoWayMsg
void
PACKETCHECKRRR_SERVER_CLASS::SendPacket(UINT8 command, UINT32 payload)
{
  switch(command) {
    case HEADER:
      length = UINT16(payload);
      dataReceived = 0;
      assert(length < sizeof(packet));
      printf("Received header %d\n", (UINT8) payload); 
      break;
    case DATA:
      packet[dataReceived] = (UINT8) payload;
      dataReceived++;
      printf("Received %x\n", (UINT8) payload); 
      //End of packet - do some stuff.
      if(dataReceived == length) {
        int crc = crc32 (packet ,length-4);
        int expectedcrc = (((UINT32)packet[length-4]) << 24) + 
	                  (((UINT32)packet[length-3]) << 16) + 
	                  (((UINT32)packet[length-2]) << 8) + 
	                  (((UINT32)packet[length-1]) << 0); 
        if(crc == expectedcrc) {
          printf("Received matching CRC %x\n", crc);
	} else {
          printf("Received non-matching CRC %x\n", crc);
	}
        
      }
      break;
  }
}



