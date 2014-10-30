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

class ScramblerIndication : public ScramblerIndicationWrapper {

public:
  ScramblerIndication(int id, PortalPoller *poller = 0) : ScramblerIndicationWrapper(id, poller) { }
  virtual void scramblerOutput (uint32_t control, uint32_t data) {
    fprintf(stderr, "  scramblerOutput control=%x data=%x\n", control, data);
  }
  virtual void descramblerOutput (uint32_t control, uint32_t data) {
    fprintf(stderr, "descramblerOutput control=%x data=%x\n", control, data);
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
  for (int i = 0; i < 1000; i++) {

    request->scramblerInput(i);
    // wait for values to be checked
    sem_wait(&sem);
  }

  //while(true){sleep(2);}
}
