#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>
#include <glib.h>

#include "asim/rrr/service_ids.h"
#include "asim/provides/airblue_phy_packet_check.h"

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
    // Glib needs this or it complains
    if(!g_thread_supported()) {
      g_thread_init(NULL);
    }
    // Set up my FIFOs
    headerQ = g_async_queue_new();
    dataQ   = g_async_queue_new();
}

// uninit
void
PACKETCHECKRRR_SERVER_CLASS::Uninit()
{
    Cleanup();
    PLATFORMS_MODULE_CLASS::Uninit();
    g_async_queue_unref(headerQ);
    g_async_queue_unref(dataQ);
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

// This times out after 5 minutes
HEADER_80211_PHY *PACKETCHECKRRR_SERVER_CLASS::getNextHeaderTimed( int seconds )
{
  GTimeVal time;
  g_get_current_time(&time);
  // Second arg is in microseconds
  g_time_val_add(&time, seconds*1000000);

  return (HEADER_80211_PHY*)g_async_queue_timed_pop(headerQ,&time);
}

HEADER_80211_PHY *PACKETCHECKRRR_SERVER_CLASS::getNextHeader()
{
  return (HEADER_80211_PHY*)g_async_queue_pop(headerQ);
}

UINT8 *PACKETCHECKRRR_SERVER_CLASS::getNextPacket()
{
  return (UINT8*)g_async_queue_pop(dataQ);
}

// F2HTwoWayMsg
void
PACKETCHECKRRR_SERVER_CLASS::SendPacket(UINT8 command, UINT32 payload)
{
  HEADER_80211_PHY *headerPtr;
  int rate;
  switch(command) {

    case HEADER:
      length = payload & 0xfff;
      rate = payload >> 12;
      dataReceived = 0;
      packet = (UINT8*) malloc(8192);
      assert(length < 8192);
      headerPtr = (HEADER_80211_PHY*) malloc(sizeof(HEADER_80211_PHY));
      headerPtr->length = length;
      headerPtr->rate   = rate;
      g_async_queue_push(headerQ,headerPtr);       
      // handle the special case where no data is expected to come...
      if(length == 0) {
	g_async_queue_push(dataQ,packet);
        packet =  NULL;     
      }

      break;

    case DATA:
      packet[dataReceived] = (UINT8) payload;
      dataReceived++;
      if(length == dataReceived) {
	g_async_queue_push(dataQ,packet);
        packet =  NULL;     
      }
      break;
  }
}



