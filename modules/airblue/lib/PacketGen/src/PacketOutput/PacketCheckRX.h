#ifndef _PACKETCHECKRRR_
#define _PACKETCHECKRRR_

#include <stdio.h>
#include <sys/time.h>
#include <glib.h>

#include "asim/provides/low_level_platform_interface.h"
#include "asim/provides/rrr.h"
#include "asim/provides/airblue_phy_packet_check.h"

// this module provides the RRRTest server functionalities

typedef enum {
  PicWidth = 0,
  PicHeight = 1,
  EndOfFrame = 2,
  EndOfFile = 3
} FinalOutputControl; 



typedef class PACKETCHECKRRR_SERVER_CLASS* PACKETCHECKRRR_SERVER;
class PACKETCHECKRRR_SERVER_CLASS: public RRR_SERVER_CLASS,
                               public PLATFORMS_MODULE_CLASS
{
  private:
    // self-instantiation
    static PACKETCHECKRRR_SERVER_CLASS instance;
    FILE *outputFile;
    UINT32 length;
    UINT32 dataReceived;
    UINT8 *packet; // Large buffer for packets
    // server stub
    RRR_SERVER_STUB serverStub;
    GAsyncQueue *headerQ;
    GAsyncQueue *dataQ;

  public:
    PACKETCHECKRRR_SERVER_CLASS();
    ~PACKETCHECKRRR_SERVER_CLASS();

    // static methods
    static PACKETCHECKRRR_SERVER GetInstance() { return &instance; }

    // required RRR methods
    void Init(PLATFORMS_MODULE);
    void Uninit();
    void Cleanup();
    bool Poll();

    UINT32 *getNextLength();
    UINT32 *getNextLengthTimed(int seconds);
    UINT8  *getNextPacket();

    //
    // RRR service methods
    //
    void SendPacket(UINT8 command, UINT32 payload);
};



// include server stub
#include "asim/rrr/server_stub_PACKETCHECKRRR.h"

#endif
