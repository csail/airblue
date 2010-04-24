#ifndef __AIRBLUE_DRIVER__
#define __AIRBLUE_DRIVER__

#include "asim/provides/virtual_platform.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/rrr/client_stub_CBUSCONTROLRRR.h"

typedef class AIRBLUE_DRIVER_CLASS* AIRBLUE_DRIVER;
class AIRBLUE_DRIVER_CLASS
{
  private:
    CBUSCONTROLRRR_CLIENT_STUB clientStub;


  public:
    AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p);
    ~AIRBLUE_DRIVER_CLASS();

    // init
    void Init();

    // main
    void Main();
};

#endif
