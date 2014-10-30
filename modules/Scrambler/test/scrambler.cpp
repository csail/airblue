//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2014 Quanta Resarch Cambridge, Inc.
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

#include <assert.h>
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

#include <pthread.h>
#include <semaphore.h>

#include <GeneratedTypes.h>
#include <ScramblerRequest.h>
#include <ScramblerIndication.h>

#undef DEBUG
#define DEBUG

static sem_t sem;

int error = 0;

class ScramblerIndication : public ScramblerIndicationWrapper {

public:
  ScramblerIndication(int id, PortalPoller *poller = 0) : ScramblerIndicationWrapper(id, poller) { }
  virtual void putOutput (uint32_t inputControl, uint32_t inputData, uint32_t scrambledControl, uint32_t scrambledData, uint32_t descrambledControl, uint32_t descrambledData) {
    if (scrambledData == inputData || descrambledData != inputData) {
      fprintf(stderr, "Error!\n");
      fprintf(stderr, "descramblerOutput input=%x.%x scrambled=%x.%x descrambled=%x.%x\n", inputControl, inputData, scrambledControl, scrambledData, descrambledControl, descrambledData);
      error = 1;
    }
    sem_post(&sem);
  }
};

int main(int argc, const char **argv)
{
  ScramblerRequestProxy *request = new ScramblerRequestProxy(IfcNames_ScramblerRequestPortal);
  ScramblerIndication *ind = new ScramblerIndication(IfcNames_ScramblerIndicationPortal);
  
  sem_init(&sem, 0, 0);

  portalExec_start();

  // send input to hardware
  int limit = 4096;
  int step = 17;
  fprintf(stderr, "Running test in input values between 0 and %d stepping by %d\n", limit, step);
  for (int i = 0; i < limit; i += step) {

    if ((i % 128) == 0)
      fprintf(stderr, "running test on i=%d\n", i);
    request->putInput(i);
    // wait for values to be checked
    sem_wait(&sem);
  }

  //while(true){sleep(2);}
  return error;
}
