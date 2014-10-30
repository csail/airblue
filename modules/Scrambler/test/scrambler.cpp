
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
  virtual void putOutput (uint32_t control, uint32_t data) {
    fprintf(stderr, "putOutput control=%x data=%x\n", control, data);
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

    request->putInput(i);
    // wait for values to be checked
    sem_wait(&sem);
  }

  //while(true){sleep(2);}
}
