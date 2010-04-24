#ifndef __GCT_DRIVER__
#define __GCT_DRIVER__

#include "asim/provides/virtual_platform.h"
#include "asim/rrr/client_stub_SPIMASTERRRR.h"


typedef class GCT_DRIVER_CLASS* GCT_DRIVER;
class GCT_DRIVER_CLASS
{
  private:
    SPIMASTERRRR_CLIENT_STUB clientStub;


  public:
    GCT_DRIVER_CLASS(PLATFORMS_MODULE p);
    ~GCT_DRIVER_CLASS();

    // init
    void Init();

    // main
    void Main();
};

#endif
