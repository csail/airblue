#ifndef __HostControl__
#define __HostControl__

#include "asim/rrr/client_stub_CBUSVECTORCONTROLRRR.h"

class HostControl
{
  public:
    static CBUSVECTORCONTROLRRR_CLIENT_STUB Get(PLATFORMS_MODULE p);
};

#endif
