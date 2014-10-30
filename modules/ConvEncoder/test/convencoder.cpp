
#include <assert.h>
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

#include <pthread.h>
#include <semaphore.h>

#include <GeneratedTypes.h>
#include <ConvEncoderRequest.h>
#include <ConvEncoderIndication.h>

#undef DEBUG
#define DEBUG

static sem_t sem;

class ConvEncoderIndication : public ConvEncoderIndicationWrapper {

public:
  ConvEncoderIndication(int id, PortalPoller *poller = 0) : ConvEncoderIndicationWrapper(id, poller) { }
  virtual void putOutput (uint32_t control, uint32_t data) {
    fprintf(stderr, "putOutput control=%x data=%x\n", control, data);
    sem_post(&sem);
  }
};

int main(int argc, const char **argv)
{
  ConvEncoderRequestProxy *request = new ConvEncoderRequestProxy(IfcNames_ConvEncoderRequestPortal);
  ConvEncoderIndication *ind = new ConvEncoderIndication(IfcNames_ConvEncoderIndicationPortal);
  
  sem_init(&sem, 0, 0);

  portalExec_start();

  // send input to hardware
  for (int i = 0; i < 1000; i++) {

    request->putInput((i == 0), i);
    // wait for values to be checked
    sem_wait(&sem);
  }

  //while(true){sleep(2);}
}
