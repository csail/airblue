#include <stdio.h>

#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"

using namespace std;
 
// constructor
CONNECTED_APPLICATION_CLASS::CONNECTED_APPLICATION_CLASS(VIRTUAL_PLATFORM vp): 
  airblueDriver(new AIRBLUE_DRIVER_CLASS(this)),
  airblueFrontend(new RF_DRIVER_CLASS(this))
{
}

// destructor
CONNECTED_APPLICATION_CLASS::~CONNECTED_APPLICATION_CLASS()
{
}

// init
void
CONNECTED_APPLICATION_CLASS::Init()
{
}

// main
void
CONNECTED_APPLICATION_CLASS::Main()
{
  // Eventually we'll call the frontend initialization here. 
  airblueFrontend->Main();
  airblueDriver->Main();
}

