#ifndef _TRANSACTORRRR_
#define _TRANSACTORRRR_

#include <stdio.h>
#include <sys/time.h>

#include "asim/provides/low_level_platform_interface.h"
#include "asim/provides/airblue_transactor.h"
#include "asim/provides/rrr.h"

// this module provides the RRRTest server functionalities

typedef class TRANSACTORRRR_SERVER_CLASS* TRANSACTORRRR_SERVER;
class TRANSACTORRRR_SERVER_CLASS: public RRR_SERVER_CLASS,
                                  public PLATFORMS_MODULE_CLASS
{
  private:
    // self-instantiation
    static TRANSACTORRRR_SERVER_CLASS instance;

    // server stub
    RRR_SERVER_STUB serverStub;
    
  public:
    TRANSACTORRRR_SERVER_CLASS();
    ~TRANSACTORRRR_SERVER_CLASS();

    // static methods
    static TRANSACTORRRR_SERVER GetInstance() { return &instance; }

    // required RRR methods
    void Init(PLATFORMS_MODULE);
    void Uninit();
    void Cleanup();
    bool Poll();

    //
    // RRR service methods
    //
    UINT8 GetXactorType (UINT8 dummy);
    UINT32 GetXactorClkCtrl (UINT32 dummy);
};

// include server stub
#include "asim/rrr/server_stub_TRANSACTORRRR.h"

#endif
