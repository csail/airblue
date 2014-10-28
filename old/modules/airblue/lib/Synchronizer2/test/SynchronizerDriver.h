#ifndef _SYNCHRONIZERDRIVER_
#define _SYNCHRONIZERDRIVER_

#include <stdio.h>
#include <sys/time.h>

#include "asim/provides/low_level_platform_interface.h"
#include "asim/provides/rrr.h"

#include "asim/rrr/client_stub_SYNCHRONIZERDRIVER.h"

#include "channel.h"

// this module provides the RRRTest server functionalities

typedef class SYNCHRONIZERDRIVER_SERVER_CLASS* SYNCHRONIZERDRIVER_SERVER;
class SYNCHRONIZERDRIVER_SERVER_CLASS: public RRR_SERVER_CLASS,
                               public PLATFORMS_MODULE_CLASS
{
  private:
    // self-instantiation
    static SYNCHRONIZERDRIVER_SERVER_CLASS instance;

    // server stub
    RRR_SERVER_STUB serverStub;
    SYNCHRONIZERDRIVER_CLIENT_STUB clientStub;

    UINT64 sendCounter;
    UINT64 recvCounter;

    UINT64 packetCounter;

    std::deque<UINT64> expected;

    UINT32 falsePositives;
    UINT32 early;
    UINT32 misses;
    UINT32 success;

    UINT64 GetSamples3();

    channel ch;
    
  public:
    SYNCHRONIZERDRIVER_SERVER_CLASS();
    ~SYNCHRONIZERDRIVER_SERVER_CLASS();

    // static methods
    static SYNCHRONIZERDRIVER_SERVER GetInstance() { return &instance; }

    // required RRR methods
    void Init(PLATFORMS_MODULE);
    void Uninit();
    void Cleanup();
    bool Poll();

    //
    // RRR service methods
    //
    void SynchronizerOut6(UINT8 syncs);
};

// include server stub
#include "asim/rrr/server_stub_SYNCHRONIZERDRIVER.h"

#endif
