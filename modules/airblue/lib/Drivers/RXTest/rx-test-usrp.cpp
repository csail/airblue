#include <stdio.h>
#include <pthread.h>

#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/airblue_phy_packet_check.h"
#include "asim/provides/airblue_soft_mac.h"

using namespace std;
 
// This thread will suck in data from the various instrumentation
// points and process it asynchronously.  DO NOT USE RRR! THIS WILL
// BRING DEATH!!!

void * ProcessPackets(void *inputComplete) {
  PACKETCHECKRRR_SERVER packetCheck = PACKETCHECKRRR_SERVER_CLASS::GetInstance();

  HEADER_80211_PHY *headerPtr = NULL;
  UINT8 *packetPtr = NULL;

  // Set up the packet dissector
  KisBuiltinDissector *dissector = new KisBuiltinDissector();

  // NULL means we timed out..
  while(1) { 
    if((headerPtr = packetCheck->getNextHeaderTimed(30)) == NULL) {
      if(*((UINT32*)inputComplete)) {
        break;
      } else {
        continue;
      }
    }
    //get packet data
    printf("Packet Length: %d Rate: %d\n", headerPtr -> length, headerPtr->rate); 
    packetPtr = packetCheck->getNextPacket();
    UINT32 length = headerPtr->length;
    for(int i = 0; i < length; i++) { 
      //printf("Received %x\n", packetPtr[i]); 
      //End of packet - do some stuff.
    }

    UINT32 crc = 1;
    UINT32 expectedcrc = 0;
     
    if(length > 8) {
      crc = crc32 (packetPtr ,length-4);
      expectedcrc = (((UINT32)packetPtr[length-4]) << 24) + 
	             (((UINT32)packetPtr[length-3]) << 16) + 
	             (((UINT32)packetPtr[length-2]) << 8) + 
	             (((UINT32)packetPtr[length-1]) << 0); 
    }

    if(crc == expectedcrc && length >= 14) {
      printf("Received matching CRC %x\n", crc);

      // If it's good, let's try to process the packet using kismet
      kis_packet *kisPacketPtr = new kis_packet();
      kis_datachunk *kisDataPtr = new kis_datachunk();
      kis_fcs_bytes *kisFCS = new kis_fcs_bytes();
      kisDataPtr->data = packetPtr;
      kisDataPtr->length = length-4;
      kisDataPtr->dlt = KDLT_IEEE802_11;
      
      kisFCS->fcs[0] = (guint8)*(packetPtr + length - 4);
      kisFCS->fcs[1] = (guint8)*(packetPtr + length - 3);
      kisFCS->fcs[2] = (guint8)*(packetPtr + length - 2);
      kisFCS->fcs[3] = (guint8)*(packetPtr + length - 1);
      kisFCS->fcsvalid = 1;

      kisPacketPtr->insert(_PCM(PACK_COMP_80211FRAME), kisDataPtr);
      kisPacketPtr->insert(_PCM(PACK_COMP_FCSBYTES), kisFCS);

      dissector->ieee80211_dissector(kisPacketPtr);
      // We should get a packet_info back!
      kis_ieee80211_packinfo *kisInfo = (kis_ieee80211_packinfo *) kisPacketPtr->fetch(_PCM(PACK_COMP_80211));

      // leaking these strings...
      printf("Received Src: %s, Dest: %s\n", kisInfo->source_mac.Mac2String().c_str(),
	     kisInfo->dest_mac.Mac2String().c_str());
 
      // This wipes out all the things in the packet....
      delete kisPacketPtr;


    } else if (length > 8){
      printf("Received non-matching CRC %x\n", crc);
    }

    // Deallocate stuff
    free(headerPtr);
    free(packetPtr);   
  }
  printf("Process Packet thread terminating\n");
  return NULL;
}


// constructor
AIRBLUE_DRIVER_CLASS::AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p) :
   DRIVER_MODULE_CLASS(p)
{
  inputComplete = 0; 
  sataStub = new SATARRR_CLIENT_STUB_CLASS(p); 
  checkStub = new PACKETCHECKRRR_CLIENT_STUB_CLASS(p); 
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
  printf("Hello\n");

   checkStub->SetDropPacket(~0); 

  // spawn packet processing thread
  pthread_create(&processPacketsThread, NULL, &ProcessPackets, &inputComplete);

  while(1){
    printf("RX: %d TX: %d Sent: %d Dropped: %d\n", sataStub->GetRXCount(0), sataStub->GetTXCount(0), sataStub->GetSampleSent(0), sataStub->GetSampleDropped(0));
    sleep(5);
  }


  inputComplete = 1;
  printf("Finished sending trace file\n");
  // Wait for the packet processing thread to stall out
  pthread_join(processPacketsThread, NULL);
  printf("returning control to awb\n");
}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
