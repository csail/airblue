#include <stdio.h>

#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"

using namespace std;
 
// constructor
AIRBLUE_DRIVER_CLASS::AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p) :
   DRIVER_MODULE_CLASS(p)
{
   printf("driver ctor\n");
}

// destructor
AIRBLUE_DRIVER_CLASS::~AIRBLUE_DRIVER_CLASS()
{
}

// init
void
AIRBLUE_DRIVER_CLASS::Init()
{
 
}

// main
void
AIRBLUE_DRIVER_CLASS::Main()
{

}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
