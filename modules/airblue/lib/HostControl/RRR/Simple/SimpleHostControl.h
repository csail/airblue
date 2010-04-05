#ifndef _SIMPLEHOSTCONTROLRRR_
#define _SIMPLEHOSTCONTROLRRR_

#include <stdio.h>
#include <sys/time.h>

#include "asim/provides/low_level_platform_interface.h"
#include "asim/provides/airblue_host_control.h"
#include "asim/provides/rrr.h"

// this module provides the RRRTest server functionalities

typedef class SIMPLEHOSTCONTROLRRR_SERVER_CLASS* SIMPLEHOSTCONTROLRRR_SERVER;
class SIMPLEHOSTCONTROLRRR_SERVER_CLASS: public RRR_SERVER_CLASS,
                               public PLATFORMS_MODULE_CLASS
{
  private:
    // self-instantiation
    static SIMPLEHOSTCONTROLRRR_SERVER_CLASS instance;

    // server stub
    RRR_SERVER_STUB serverStub;
    
  public:
    SIMPLEHOSTCONTROLRRR_SERVER_CLASS();
    ~SIMPLEHOSTCONTROLRRR_SERVER_CLASS();

    // static methods
    static SIMPLEHOSTCONTROLRRR_SERVER GetInstance() { return &instance; }

    // required RRR methods
    void Init(PLATFORMS_MODULE);
    void Uninit();
    void Cleanup();
    bool Poll();

    //
    // RRR service methods
    //
    UINT32 GetRate (UINT32 dummy);
    UINT32 CheckBER(UINT32 errors);
};

// include server stub
#include "asim/rrr/server_stub_SIMPLEHOSTCONTROLRRR.h"

#endif
