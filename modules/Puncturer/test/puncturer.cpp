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
#include <PuncturerTestRequest.h>
#include <PuncturerTestIndication.h>

#undef DEBUG
#define DEBUG

static sem_t sem;

static int dataCount = 0;

class PuncturerTestIndication : public PuncturerTestIndicationWrapper {

public:
  PuncturerTestIndication(int id, PortalPoller *poller = 0) : PuncturerTestIndicationWrapper(id, poller) { }
  virtual void putDataCount (uint32_t count) {
    dataCount = count;
    fprintf(stderr, "dataCount=%d\n", dataCount);
    sem_post(&sem);
  }
  virtual void putOutput (uint32_t control, uint32_t data) {
    fprintf(stderr, "putOutput control=%x data=%x dataCount=%d\n", control, data, dataCount);
    if (dataCount > 0)
      sem_post(&sem);
  }
};

int main(int argc, const char **argv)
{
  PuncturerTestRequestProxy *request = new PuncturerTestRequestProxy(IfcNames_PuncturerTestRequestPortal);
  PuncturerTestIndication *ind = new PuncturerTestIndication(IfcNames_PuncturerTestIndicationPortal);
  
  sem_init(&sem, 0, 0);

  portalExec_start();

  for (int rate = 0; rate < 7; rate++) {
    // send input to hardware
    fprintf(stderr, "\n\nputNewRate rate=%d\n", rate);
    request->putNewRate(rate, 0);
    sem_wait(&sem);
    while (dataCount > 0) {
      fprintf(stderr, "putNewData dataCount=%d\n", dataCount);
      request->putNewData(dataCount);
      // wait for values to be checked
      sem_wait(&sem);
      dataCount--;
    }
  }

  //while(true){sleep(2);}
}
