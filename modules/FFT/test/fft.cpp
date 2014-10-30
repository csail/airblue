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
#include <FFTRequest.h>
#include <FFTIndication.h>

#undef DEBUG
#define DEBUG

typedef struct fft {
  int fftLength;
  int intSize;
  int fracSize;
  int *realValues;
  int *imagValues;
  double *realResult;
  double *imagResult;
  double *realInverse;
  double *imagInverse;
  double *realData;
  double *imagData;
  struct fft *next;
  struct fft *previous;
} FFT;

FFT *head = NULL;
FFT *tail = NULL;
int count = 0;

FFT *allocateFFT(int fftLength) {
  FFT *newFFT =  (FFT*)malloc(sizeof(FFT));
  if(newFFT == NULL) {
    return NULL;
  }
  newFFT->fftLength = fftLength;
  newFFT->realValues = (int *)(malloc(sizeof(int) * fftLength));
  newFFT->imagValues = (int *)(malloc(sizeof(int) * fftLength));
  newFFT->realResult = (double *)(malloc(sizeof(double) * fftLength));
  newFFT->imagResult = (double *)(malloc(sizeof(double) * fftLength));  
  newFFT->realInverse = (double *)(malloc(sizeof(double) * fftLength));
  newFFT->imagInverse = (double *)(malloc(sizeof(double) * fftLength));  
  newFFT->realData = (double *)(malloc(sizeof(double) * fftLength));
  newFFT->imagData = (double *)(malloc(sizeof(double) * fftLength));  
  return newFFT;
}

void freeFFT(FFT *fft) {
  free(fft->realValues);
  free(fft->imagValues);
  free(fft->realResult);
  free(fft->imagResult);
  free(fft->realInverse);
  free(fft->imagInverse);
  free(fft->realData);
  free(fft->imagData);
  free(fft);
}

int DFT(int dir,int m,double *x1,double *y1)
{
   long i,k;
   double arg;
   double cosarg,sinarg;
   double *x2=NULL,*y2=NULL;

   x2 = (double *)(malloc(m*sizeof(double)));
   y2 = (double *)(malloc(m*sizeof(double)));
   if (x2 == NULL || y2 == NULL)
      return 0;

   for (i=0;i<m;i++) {
      x2[i] = 0;
      y2[i] = 0;
      arg = - dir * 2.0 * 3.141592654 * (double)i / (double)m;
      for (k=0;k<m;k++) {
         cosarg = cos(k * arg);
         sinarg = sin(k * arg);
         x2[i] += (x1[k] * cosarg - y1[k] * sinarg);
         y2[i] += (x1[k] * sinarg + y1[k] * cosarg);
      }
   }

   /* Copy the data back */
   if (dir == 1) {
      for (i=0;i<m;i++) {
         x1[i] = x2[i] ;
         y1[i] = y2[i] ;
      }
   } else {
      for (i=0;i<m;i++) {
         x1[i] = x2[i];
         y1[i] = y2[i];
      }
   }

   free(x2);
   free(y2);
   return 1;
}


void generateFFTValues (int fftSize, int intBitSize, int fracBitSize) {
  int i;
  FFT *next;
  int intSize = intBitSize;
  int fracSize = fracBitSize;
  int *realValues, *imagValues;  
  double *realResult, *imagResult, *realInput, *imagInput, *realInverse,  *imagInverse;   

  printf("Call to generateFFTValues: fftSize: %d,realBitSz: %d, fracBitSz: %d\n", 
	 fftSize,
         intBitSize,
         fracBitSize);
  next = allocateFFT(fftSize);

  // link up 
  next->next = head;
  head = next;
  next -> previous = NULL;
  if(tail == NULL) {
    tail = next;
  }
  realValues = next->realValues;
  imagValues = next->imagValues;
  imagResult = next->imagResult;
  realResult = next->realResult;
  imagResult = next->imagResult;
  realInput = next->realData;
  imagInput = next->imagData;
  realInverse = next->realInverse;
  imagInverse = next->imagInverse;
  next->intSize = intBitSize;
  next->fracSize = fracBitSize;


  assert(fftSize);

  #ifdef DEBUG
    printf("C Input\n");
  #endif
  for(i = 0; i < fftSize; i++) {
    if (i == 0) {
      realValues[i] = fftSize << fracSize;
      imagValues[i] = 8*fftSize << fracSize;
    } else {
      realValues[i] = 0;
      imagValues[i] = 0;
    }

    realInput[i] = (realValues[i]/((float)(1<<fracSize)));
    imagInput[i] = (imagValues[i]/((float)(1<<fracSize)));

    // copy to realResult, and then we'll compute the DFT in place
    realResult[i] = realInput[i];
    imagResult[i] = imagInput[i];

    realInverse[i] = realInput[i];
    imagInverse[i] = imagInput[i];

    #ifdef DEBUG
      printf("C Input [%d]  %f+%fi  \n",i,realInput[i],imagInput[i]);
    #endif
  }

  DFT(1,fftSize,realResult,imagResult);
  DFT(1,fftSize,realInverse,imagInverse);
  DFT(1,fftSize,realInverse,imagInverse);

  #ifdef DEBUG
    printf("\r\n");
    for(i = 0; i < fftSize; i++) {
      printf("C FFT[%d] (orig,time,freq): %f+%fi %f+%fi %f+%fi \r\n", i, realInput[i], imagInput[i],realResult[i],imagResult[i], realInverse[i]/fftSize, imagInverse[i]/fftSize);
    }
  #endif

}


int getRealInput(int index) {
  return head->realValues[index];
}

int checkRealResult(int index, int result) {
  int *realValues = tail->realValues;
  double *realResult = tail->realResult;
  int intSize = tail->intSize;
  int fracSize = tail->fracSize;
  int indexShift = (index >= tail->fftLength/2)?index - tail->fftLength/2:index + tail->fftLength/2; 
 
  #ifdef DEBUG
  printf("Index shift: %d\n", indexShift);
  printf("Real result[%d]: %f, expect %f (%x expect %x) ", index, result/((double) (1<<fracSize)), realResult[indexShift], result, realValues[indexShift]);
  #endif
  if((realResult[indexShift] - ((float)2048)/(1<<fracSize) < result/((double) (1<<fracSize))) &&
     (realResult[indexShift] + ((float)2048)/(1<<fracSize) > result/((double) (1<<fracSize)))) {
    printf("okay\n");
    return 0;
  } else {
    printf("error\n");
    return 1;
  }
} 

int getImagInput(int index) {
  return head->imagValues[index];
}

int checkImagResult(int index, int result ) {
  int *imagValues = tail->imagValues;
  double *imagResult = tail->imagResult;
  int intSize = tail->intSize;
  int fracSize = tail->fracSize;
  int indexShift = (index >= tail->fftLength/2)?index - tail->fftLength/2:index + tail->fftLength/2; 
  
  #ifdef DEBUG
  printf("Imag result[%d]: %f,  expect %f max delta: %f (%x expect %x)", index, result/((double) (1<<fracSize)), imagResult[indexShift],
	 ((float)2048)/(1<<fracSize),
	 result, imagValues[indexShift]);
  #endif
  if((imagResult[indexShift] - ((float)2048)/(1<<fracSize) < result/((double) (1<<fracSize))) &&
     (imagResult[indexShift] + ((float)2048)/(1<<fracSize) > result/((double) (1<<fracSize)))) {
    printf("okay\n");
    return 0;
  }
  else {
    printf("error\n");
    return 1;
  }
} 


void freeLast() {
  FFT *old = tail;
  #ifdef DEBUG
    printf("Calling free last\n");
  #endif
  if(old != NULL) {
    tail = old->previous;
    freeFFT(old);
  }
}



static sem_t sem;

class FFTIndication : public FFTIndicationWrapper {

public:
  FFTIndication(int id, PortalPoller *poller = 0) : FFTIndicationWrapper(id, poller) { }
  virtual void checkOutput ( const uint32_t i, const FX1616 rv, const FX1616 iv ) {
    fprintf(stderr, "checkOutput %d %08x %08x\n", i, *(int *)&rv, *(int *)&iv);
    checkRealResult(i, *(int *)&rv);
    checkImagResult(i, *(int *)&iv);
    if (i == tail->fftLength - 1) {
      ::freeLast();
      sem_post(&sem);
    }
  }
  virtual void generateFFTValues ( const uint32_t fftSize, const uint32_t realBitSize, const uint32_t imagBitSize ) {
    fprintf(stderr, "generateFFTValues size=%d %d %d\n", fftSize, realBitSize, imagBitSize);
    ::generateFFTValues(fftSize, realBitSize, imagBitSize);
    sem_post(&sem);
  }
  virtual void freeLast (  ) {
  }
};

int main(int argc, const char **argv)
{
  FFTRequestProxy *request = new FFTRequestProxy(IfcNames_FFTRequestPortal);
  FFTIndication *ind = new FFTIndication(IfcNames_FFTIndicationPortal);
  
  sem_init(&sem, 0, 0);

  portalExec_start();

  // wait for generateFFTValues indication
  sem_wait(&sem);
  
  // now send input to hardware
  FFT *fft = head;
  for (int i = 0; i < fft->fftLength; i++) {
    FX1616 rv = *(FX1616*)&fft->realValues[i];
    FX1616 iv = *(FX1616*)&fft->imagValues[i];
    fprintf(stderr, "wrote input %d %x %x\n", i, *(int*)&rv, *(int*)&iv);
    request->putInput(rv, iv);
  }


  // wait for values to be checked
  sem_wait(&sem);

  //while(true){sleep(2);}
}
