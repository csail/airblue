
#ifndef _CHANNEL_RRR_
#define _CHANNEL_RRR_

#include <stdio.h>
#include <sys/time.h>

#include "asim/provides/low_level_platform_interface.h"
#include "asim/provides/rrr.h"

//#include "asim/rrr/client_stub_CHANNEL_RRR.h"
#define TYPES_ONLY
#include "asim/rrr/server_stub_CHANNEL_RRR.h"
#undef TYPES_ONLY

#include "channel.h"

typedef class CHANNEL_RRR_SERVER_CLASS* CHANNEL_RRR_SERVER;
class CHANNEL_RRR_SERVER_CLASS: public RRR_SERVER_CLASS, public PLATFORMS_MODULE_CLASS
{
  private:
    // self-instantiation
    static CHANNEL_RRR_SERVER_CLASS instance;

    channel ch;

    // server stub
    RRR_SERVER_STUB serverStub;

    // client stub
    //CHANNEL_RRR_CLIENT_STUB clientStub;

    int count;    

  public:
    CHANNEL_RRR_SERVER_CLASS();
    ~CHANNEL_RRR_SERVER_CLASS();

    // static methods
    static CHANNEL_RRR_SERVER GetInstance() { return &instance; }

    // required RRR methods
    void Init(PLATFORMS_MODULE);
    void Uninit();
    void Cleanup();

    //
    // RRR service methods
    //

    //UINT32 Channel (UINT32 sample, UINT32 cycle);
    // void Channel (MESSAGE sample, UINT32 cycle);
    OUT_TYPE_Channel
    Channel (
        UINT8 size,
        UINT32 data0, UINT32 data1, UINT32 data2, UINT32 data3, UINT32 data4,
        UINT32 data5, UINT32 data6, UINT32 data7, UINT32 data8, UINT32 data9,
        UINT32 cycle );

};



// include server stub
#include "asim/rrr/server_stub_CHANNEL_RRR.h"

#endif
