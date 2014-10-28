#include <math.h>
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>

#define BER   0   // bit error rate
double ber = 
#ifdef BER 
BER; 
#else
0.1;
#endif

//#define FTIME 1000000 // no. cycles the testbench run
#define FTIME_DEFAULT 50000000000
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

// Copied from addNoise.c
// Is there a way to avoid repeating it here?
#define DEFAULT_SNR 30 // signal to noise ratio
static double get_snr()
{
  static double snr = 0.0;
  if (snr == 0.0) {
    char* snr_str = getenv("ADDNOISE_SNR");
    if (snr_str)
      snr = strtod(snr_str, NULL);
    if (snr == 0)
      snr = DEFAULT_SNR;
  }
  return snr;
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
  
// Table of maximum expected bit-errors for various rates/noise levels
// First column is SNR, second is max bit-errors
static double table[8][20][2] = {
 // Rate 7
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

 // Rate 6
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

 // Rate 5
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

 // Rate 4
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

 // Rate 3
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

 // Rate 2
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

 // Rate 1
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

 // Rate 0
 {
  { 20, 0.6 }, 
  { 19, 0.6 }, 
  { 18, 0.6 }, 
  { 17, 0.6 }, 
  { 16, 0.6 }, 
  { 15, 0.6 }, 
  { 14, 0.6 }, 
  { 13, 0.6 }, 
  { 12, 0.6 }, 
  { 11, 0.6 }, 
  { 10, 0.6 }, 
  {  9, 0.6 }, 
  {  8, 0.6 }, 
  {  7, 0.6 }, 
  {  6, 0.6 }, 
  {  5, 0.6 },  
  {  4, 0.6 },  
  {  3, 0.6 },  
  {  2, 0.6 },  
  {  1, 0.6 } 
 },

};

int check_ber(unsigned int errors, unsigned int totals)
{
  double snr = get_snr();
  int rate = nextRate();
  
  double max_errors;
  double table_snr;
  double ber = ((double) errors) / ((double) totals);

  int i = 0;
  do {
    table_snr = table[rate][i][0];
    max_errors = table[rate][i][1];
    ++i;
  } while (i < 20 && snr < table_snr);

  printf("BER report! snr=%0.2lf db, expected fewer than %1f (at %1f db) and was %1f\n",
  snr, max_errors, table_snr, ber);

  if (ber > max_errors) {
    return 0;
  }

  return 1;
}
