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
  union {
    UINT32 whole;
    INT16 pieces[2];
  } sample;
    
  int count=0;
  int factor;

  printf("Past Init\n");

  // We expect a 16.16 complex trace (little endian)
  inputFile = fopen("input.trace","r");
  if(inputFile == NULL) {
    printf("Did not find trace file\n");
    return;
  }
  
  for(factor = 0; factor < 1; factor++) {
    rewind(inputFile);
    while(fread(&sample, sizeof(UINT32), 1, inputFile)) {
      //if(count%1000 == 0)
      //printf("main: %d %d\n",  sample.pieces[0]*3, sample.pieces[1]*3);
      count++;      
      sample.pieces[0] = sample.pieces[0]*3; 
      sample.pieces[1] = sample.pieces[1]*3; 
      clientStub->IQStream(sample.whole);
    }
  } 
   
}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
