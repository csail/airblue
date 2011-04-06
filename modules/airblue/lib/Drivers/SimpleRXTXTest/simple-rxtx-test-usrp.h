#ifndef __AIRBLUE_DRIVER__
#define __AIRBLUE_DRIVER__

#include <pthread.h>

#include "asim/provides/virtual_platform.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/connected_application.h"
#include "asim/rrr/client_stub_PACKETCHECKRRR.h"
#include "asim/rrr/client_stub_SATARRR.h"

typedef class AIRBLUE_DRIVER_CLASS* AIRBLUE_DRIVER;
class AIRBLUE_DRIVER_CLASS : public DRIVER_MODULE_CLASS
{
  private:
    pthread_t processPacketsThread;
    int inputComplete;
    SATARRR_CLIENT_STUB        sataStub;
    PACKETCHECKRRR_CLIENT_STUB checkStub;

  public:
    AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p);
    ~AIRBLUE_DRIVER_CLASS();

    // init
    void Init();

    // main
    void Main();

};


#endif
