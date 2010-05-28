#ifndef _SOFT_PHY_PACKET_RRR_
#define _SOFT_PHY_PACKET_RRR_

#include <stdio.h>
#include <sys/time.h>

#include "asim/provides/low_level_platform_interface.h"
#include "asim/provides/airblue_host_control.h"
#include "asim/provides/rrr.h"

typedef class SOFT_PHY_PACKET_RRR_SERVER_CLASS* SOFT_PHY_PACKET_RRR_SERVER;
class SOFT_PHY_PACKET_RRR_SERVER_CLASS: public RRR_SERVER_CLASS,
                               public PLATFORMS_MODULE_CLASS
{
  private:
    // self-instantiation
    static SOFT_PHY_PACKET_RRR_SERVER_CLASS instance;

    // server stub
    RRR_SERVER_STUB serverStub;
    
  public:
    SOFT_PHY_PACKET_RRR_SERVER_CLASS();
    ~SOFT_PHY_PACKET_RRR_SERVER_CLASS();

    // static methods
    static SOFT_PHY_PACKET_RRR_SERVER GetInstance() { return &instance; }

    // required RRR methods
    void Init(PLATFORMS_MODULE);
    void Uninit();
    void Cleanup();
    bool Poll();

    //
    // RRR service methods
    //
    UINT32 SendPacket(INT32 predicted_ber, UINT32 errors, UINT32 total);
};

// include server stub
#include "asim/rrr/server_stub_SOFT_PHY_PACKET_RRR.h"

#endif
