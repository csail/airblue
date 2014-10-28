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

    double ber_sum;
    UINT32 bits;
    
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

    void SendHints(UINT32 hints_1, UINT32 hints_2, UINT32 hints_3, UINT8 rate, UINT8 last);
};

#include "table_r0.h"
#include "table_r1.h"
#include "table_r2.h"
#include "table_r3.h"
#include "table_r4.h"
#include "table_r5.h"
#include "table_r6.h"
#include "table_r7.h"

inline double
get_ber(UINT8 hint, UINT8 rate) {
    switch (rate) {
        case 0: return get_ber_r0(hint);
        case 1: return get_ber_r1(hint);
        case 2: return get_ber_r2(hint);
        case 3: return get_ber_r3(hint);
        case 4: return get_ber_r4(hint);
        case 5: return get_ber_r5(hint);
        case 6: return get_ber_r6(hint);
        case 7: return get_ber_r7(hint);
    }
    printf("get_ber: unexpected rate %d\n", rate);
    exit(1);
    return 0.0;
}

// include server stub
#include "asim/rrr/server_stub_SOFT_PHY_PACKET_RRR.h"

#endif
