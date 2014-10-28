#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/airblue_host_control.h"
#include "asim/dict/AIRBLUE_REGISTER_MAP.h"

using namespace std;

class AIRBLUE_MAC_DRIVER_CLASS : public DRIVER_MODULE_CLASS
{
  public:
    AIRBLUE_MAC_DRIVER_CLASS(PLATFORMS_MODULE p) :
        DRIVER_MODULE_CLASS(p) {}

    // init
    void Init() {
        CBUSVECTORCONTROLRRR_CLIENT_STUB clientStub = HostControl::Get(parent);
        clientStub->Write(0,AIRBLUE_REGISTER_MAP_MAC_ADDR_2, 0);
        clientStub->Write(0,AIRBLUE_REGISTER_MAP_MAC_ADDR_1, 88);
        clientStub->Write(0,AIRBLUE_REGISTER_MAP_MAC_ADDR_0, 1);
     
        clientStub->Write(1,AIRBLUE_REGISTER_MAP_MAC_ADDR_2, 0);
        clientStub->Write(1,AIRBLUE_REGISTER_MAP_MAC_ADDR_1, 23);
        clientStub->Write(1,AIRBLUE_REGISTER_MAP_MAC_ADDR_0, 1);
     
        clientStub->Write(1,AIRBLUE_REGISTER_MAP_TARGET_MAC_ADDR_2, 0);
        clientStub->Write(1,AIRBLUE_REGISTER_MAP_TARGET_MAC_ADDR_1, 88);
        clientStub->Write(1,AIRBLUE_REGISTER_MAP_TARGET_MAC_ADDR_0, 1);
   }
};

// register driver
static RegisterDriver<AIRBLUE_MAC_DRIVER_CLASS> X;
