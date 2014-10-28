#include <assert.h>
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

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
    int period = ((rand()%8)==0)?1:0;
    int mag = (rand()%(1<<(intSize+fracSize-1)));
    realValues[i] = period * mag;
    imagValues[i] = 0;
     
      /*if(realValues[i] > ((1<<(intSize+fracSize-1))-1)) {
      realResult[i] = ((realValues[i])/((float)(1<<fracSize)) - (1<<(intSize)))/fftSize;    
      realValues[i] = realValues[i] - (1<<(intSize+fracSize));      
      
      } else*/ {
      realResult[i] = (realValues[i]/((float)(1<<fracSize)))/fftSize;
    }

    /*if(imagValues[i] > ((1<<(intSize+fracSize-1))-1)) {
      imagResult[i] = (imagValues[i]/((float)(1<<fracSize))- (1<<(intSize)))/fftSize;
      imagValues[i] = imagValues[i] - (1<<(intSize+fracSize)); 
      } else*/ {
      imagResult[i] = (imagValues[i]/((float)(1<<fracSize)))/fftSize;    
    }

    realValues[i] = realValues[i]/fftSize;
    imagValues[i] = imagValues[i]/fftSize;
    realInput[i] = realResult[i];
    imagInput[i] = imagResult[i];
    realInverse[i] = realResult[i];
    imagInverse[i] = imagResult[i];

    
    #ifdef DEBUG
      printf("C Input [%d]  %f+%fi  \n",i,realResult[i],imagResult[i]);
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
  double *realResult = tail->realResult;
  int intSize = tail->intSize;
  int fracSize = tail->fracSize;
  int indexShift = (index >= tail->fftLength/2)?index - tail->fftLength/2:index + tail->fftLength/2; 
 
  #ifdef DEBUG
  printf("Index shift: %d\n", indexShift);
  printf("Real result[%d]: %f, expect %f ", index, result/((double) (1<<fracSize)), realResult[indexShift]);
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
  double *imagResult = tail->imagResult;
  int intSize = tail->intSize;
  int fracSize = tail->fracSize;
  int indexShift = (index >= tail->fftLength/2)?index - tail->fftLength/2:index + tail->fftLength/2; 
  
  #ifdef DEBUG
  printf("Imag result[%d]: %f,  expect %f max delta: %f ", index, result/((double) (1<<fracSize)), imagResult[indexShift],
  ((float)2048)/(1<<fracSize));  
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
