#include "HostControl.h"

CBUSVECTORCONTROLRRR_CLIENT_STUB
HostControl::Get(PLATFORMS_MODULE p)
{
    static CBUSVECTORCONTROLRRR_CLIENT_STUB stub = NULL;
    if (stub == NULL) {
        stub = new CBUSVECTORCONTROLRRR_CLIENT_STUB_CLASS(p);
    }
    return stub;
}
