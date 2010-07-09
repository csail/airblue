#ifndef _CHECKBERHOSTCONTROLRRR_
#define _CHECKBERHOSTCONTROLRRR_

#include <stdio.h>
#include <sys/time.h>

#include "asim/provides/low_level_platform_interface.h"
#include "asim/provides/rrr.h"

// this module provides the RRRTest server functionalities

typedef class CHECKBERHOSTCONTROLRRR_SERVER_CLASS* CHECKBERHOSTCONTROLRRR_SERVER;
class CHECKBERHOSTCONTROLRRR_SERVER_CLASS: public RRR_SERVER_CLASS,
                               public PLATFORMS_MODULE_CLASS
{
  private:
    // self-instantiation
    static CHECKBERHOSTCONTROLRRR_SERVER_CLASS instance;

    // server stub
    RRR_SERVER_STUB serverStub;
    
  public:
    CHECKBERHOSTCONTROLRRR_SERVER_CLASS();
    ~CHECKBERHOSTCONTROLRRR_SERVER_CLASS();

    // static methods
    static CHECKBERHOSTCONTROLRRR_SERVER GetInstance() { return &instance; }

    // required RRR methods
    void Init(PLATFORMS_MODULE);
    void Uninit();
    void Cleanup();
    bool Poll();

    //
    // RRR service methods
    //
    UINT64 CheckBER(UINT64 errors, UINT64 total);
};

// include server stub
#include "asim/rrr/server_stub_CHECKBERHOSTCONTROLRRR.h"

#endif
