#ifndef __RF_DRIVER__
#define __RF_DRIVER__

#include "asim/provides/virtual_platform.h"

typedef class RF_DRIVER_CLASS* RF_DRIVER;
class RF_DRIVER_CLASS
{
  private:


  public:
    RF_DRIVER_CLASS(PLATFORMS_MODULE p);
    ~RF_DRIVER_CLASS();

    // init
    void Init();

    // main
    void Main();
};

#endif
