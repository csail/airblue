#ifndef __CONNECTED_APPLICATION__
#define __CONNECTED_APPLICATION__

#include <vector>

#include "asim/provides/virtual_platform.h"


typedef class DRIVER_MODULE_CLASS* DRIVER_MODULE;
class DRIVER_MODULE_CLASS : public PLATFORMS_MODULE_CLASS
{
  public:
    DRIVER_MODULE_CLASS(PLATFORMS_MODULE p) : 
        PLATFORMS_MODULE_CLASS(p) {}

    // main
    virtual void Main() {}
};


typedef class CONNECTED_APPLICATION_CLASS* CONNECTED_APPLICATION;
class CONNECTED_APPLICATION_CLASS  : public PLATFORMS_MODULE_CLASS
{
  public:
    typedef DRIVER_MODULE (*DRIVER_CTOR)(PLATFORMS_MODULE);

  private:
    std::vector<DRIVER_MODULE> drivers;

    static std::vector<DRIVER_CTOR>& DriverCtors() {
        static std::vector<DRIVER_CTOR> driverCtors;
        return driverCtors;
    }

  public:
    CONNECTED_APPLICATION_CLASS(VIRTUAL_PLATFORM vp);
    ~CONNECTED_APPLICATION_CLASS();

    // init
    void Init();

    // main
    void Main();

    static void RegisterDriver(DRIVER_CTOR ctor) {
        DriverCtors().push_back(ctor);
    }
};

template<typename DriverName>
DRIVER_MODULE callCtor(PLATFORMS_MODULE p) { return new DriverName(p); }

template<typename driverName>
struct RegisterDriver {
    RegisterDriver() {
        CONNECTED_APPLICATION_CLASS::RegisterDriver(
            CONNECTED_APPLICATION_CLASS::DRIVER_CTOR(callCtor<driverName>));
    }
};

#endif
