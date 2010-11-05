#include <stdio.h>

#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"

using namespace std;
 
// constructor
CONNECTED_APPLICATION_CLASS::CONNECTED_APPLICATION_CLASS(VIRTUAL_PLATFORM vp)
{
    vector<DRIVER_CTOR>::iterator it;
    for (it = DriverCtors().begin(); it != DriverCtors().end(); it++) {
        DRIVER_CTOR ctor = *it;
        drivers.push_back(ctor(this));
    }
}

// destructor
CONNECTED_APPLICATION_CLASS::~CONNECTED_APPLICATION_CLASS()
{
}

// init
void
CONNECTED_APPLICATION_CLASS::Init()
{
    PLATFORMS_MODULE_CLASS::Init();
}

// main
void
CONNECTED_APPLICATION_CLASS::Main()
{

  // Should split this to driver init and driver main or something
  printf("in main\n");
  vector<DRIVER_MODULE>::iterator it;
  for (it = drivers.begin(); it != drivers.end(); it++) {
      DRIVER_MODULE driver = *it;
      driver->Main();
  }
  printf("exiting main\n");
  // Eventually we'll call the frontend initialization here. 
  //airblueDriver->Main();
  //airblueFrontend->Main();
}
