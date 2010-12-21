#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <sys/stat.h>
#include <glib.h>

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
    // Glib needs this or it complains
    g_thread_init(NULL);
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
UINT32 *PACKETCHECKRRR_SERVER_CLASS::getNextLength()
{
  GTimeVal time;
  g_get_current_time(&time);
  // Second arg is in microseconds
  g_time_val_add(&time, 5*60*1000000);

  return (UINT32*)g_async_queue_timed_pop(headerQ,&time);
}

UINT8 *PACKETCHECKRRR_SERVER_CLASS::getNextPacket()
{
  return (UINT8*)g_async_queue_pop(dataQ);
}

// F2HTwoWayMsg
void
PACKETCHECKRRR_SERVER_CLASS::SendPacket(UINT8 command, UINT32 payload)
{
  UINT32 *lengthPtr;
  switch(command) {

    case HEADER:
      length = payload;
      dataReceived = 0;
      packet = (UINT8*) malloc(8192);
      assert(length < 8192);
      printf("Received header %d\n", (UINT8) payload);
      lengthPtr = (UINT32*) malloc(sizeof(UINT32));
      *lengthPtr = length;
      g_async_queue_push(headerQ,lengthPtr);       
      break;

    case DATA:
      packet[dataReceived] = (UINT8) payload;
      dataReceived++;
      printf("Received data %d\n", (UINT8) payload);
      if(length == dataReceived) {
	g_async_queue_push(dataQ,packet);
        packet =  NULL;     
      }
      break;
  }
}



