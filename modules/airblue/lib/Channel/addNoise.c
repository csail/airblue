#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>

//Noise variance
#define DEFAULT_SNR 30 // signal to noise ratio
#define PI (4*atan2(1,1))
//#define DELTA_F 100000
#define TIME_STEP 5e-8

// frequency offset (in Hz)
double delta_f = 0;
double dc_offset_real = 0; // (0 <= thisValue < 32768)
double dc_offset_imag = 0; // (0 <= thisValue < 32768)

double awgn_variance = 0.0;

int addNoise(short int real, short int imag, int rot, int res)
{
   static double lastReal = 0;
   static double lastImag = 0;
   double thisReal = real+dc_offset_real;
   double thisImag = imag+dc_offset_imag;
//   double thisReal = 0.5*real+0.5*lastReal;
//   double thisImag = 0.5*imag+0.5*lastImag;
   double rotReal, rotImag;
   double outReal, outImag;
   unsigned int returnVal;
   double x1, x2;

   if (awgn_variance == 0.0) {
     double snr = 0;
     char* snr_str = getenv("ADDNOISE_SNR");
     if (snr_str)
       snr = strtod(snr_str, NULL);
     if (snr == 0)
       snr = DEFAULT_SNR;
     awgn_variance = (0.8125*(SHRT_MAX*0.5)*pow(10,(snr*(-0.1))));
   }

   if(res != 0)
      delta_f = rand()/((double)RAND_MAX + 1) * 200000;
   //    printf("symbol location: %d, %d\n", delta_f, rot);
   rotReal = cos(2*PI*delta_f*TIME_STEP*rot);
   rotImag = sin(2*PI*delta_f*TIME_STEP*rot);
   outReal = rotReal*(double)thisReal - rotImag*(double)thisImag;
   outImag = rotReal*(double)thisImag + rotImag*(double)thisReal;
   x1 = rand()/((double)RAND_MAX + 1);
   x2 = rand()/((double)RAND_MAX + 1);
   outReal += awgn_variance*sqrt(-2*log(x1))*cos(2*PI*x2);
   outImag += awgn_variance*sqrt(-2*log(x1))*sin(2*PI*x2);
   if(outReal >= 32768)
      outReal = 32767;
   if(outReal < -32768)
      outReal = -32768;
   if(outImag >= 32768)
      outImag = 32767;
   if(outImag < -32768)
      outImag = -32768;    
   unsigned int outR = ((unsigned int)outReal)%(1<<16);
   unsigned int outI = ((unsigned int)outImag)<<16;
   returnVal = outR+outI;
   lastReal = real;
   lastImag = imag;
   return returnVal;
}


