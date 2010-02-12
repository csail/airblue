#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>

#define BER   0.01   // bit error rate
double ber = 
#ifdef BER 
BER; 
#else
0.1;
#endif

//#define FTIME 1000000 // no. cycles the testbench run
#define FTIME_DEFAULT 100000
unsigned int ftime = 
#ifdef FTIME 
FTIME; 
#else
(unsigned int)-1;
#endif

//#define RATE  0 // 0 = 6Mbps, 1 = 9Mbps, 2 = 12Mbps, 3 = 18Mbps, 4 = 24Mbps, 5 = 36Mbps, 6 = 48Mbps, 7 = 54Mbps
unsigned char rate = 
#ifdef RATE 
RATE;
#else
(unsigned char)-1;
#endif

//#define PUSHZEROS 0 // 0 = False, 1 = True
unsigned char pushzeros = 
#ifdef PUSHZEROS 
PUSHZEROS;
#else
0;
#endif


unsigned int addError()
{
   unsigned int res = 0;
   double dice;
   int i;
   for (i = 0; i < 24; i++)
      {
         res = res << 1;
         dice = ((double)rand())/((double)RAND_MAX + 1);
         if (dice < ber)
            res++;
      }

   return res;
}


unsigned char getConvOutBER()
{
   return (unsigned char)(ber * 100);
}

unsigned char nextRate()
{
  if (rate == (unsigned char)-1) {
    char* rate_str = getenv("ADDERROR_RATE");
    unsigned int new_rate = 0;
    if (rate_str)
      new_rate = atoi(rate_str);
    rate = new_rate;
  }
  return rate;
}

unsigned char viterbiMapCtrl(unsigned char ctrl)
{
   return pushzeros && ctrl;
}

unsigned int finishTime()
{
  if (ftime == (unsigned int)-1) {
    char* ftime_str = getenv("ADDERROR_CYCLES");
    unsigned int new_ftime = 0;
    if (ftime_str)
      new_ftime = atoi(ftime_str);
    if (!new_ftime)
      new_ftime = FTIME_DEFAULT;
    ftime = new_ftime;
  }
  return ftime;
}

int main()
{
   printf("BER %lf\n",ber);
   return 0;
}
