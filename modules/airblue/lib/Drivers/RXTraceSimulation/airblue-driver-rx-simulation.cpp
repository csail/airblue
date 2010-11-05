#include <stdio.h>

#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/rrr/client_stub_AIRBLUERFSIM.h"

using namespace std;
 
// constructor
AIRBLUE_DRIVER_CLASS::AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p) :
   DRIVER_MODULE_CLASS(p)
{
   clientStub = new AIRBLUERFSIM_CLIENT_STUB_CLASS(p);
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
  printf("Hello\n");

  FILE *inputFile;
  UINT32 sample;
  int count=0;

  printf("Past Init\n");

  // We expect a 16.16 complex trace (little endian)
  inputFile = fopen("input.trace","r");
  if(inputFile == NULL) {
    printf("Did not find trace file\n");
    return;
  }
  while(fread(&sample, sizeof(UINT32), 1, inputFile)) {
    if(count%1000 == 0)
      printf("main: %d\n", count);
    count++;
    clientStub->IQStream(sample);
  } 
}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
