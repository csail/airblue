#include <stdlib.h>
#include <stdio.h>

//nclude "asim/provides/airblue_host_control.h"
//nclude "asim/provides/airblue_host_control.h"

#include "check_ber.h"

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

//Grab the rate environmental variable.
#define DEFAULT_RATE 0 // BPSK, no puncture
int get_rate()
{
  int rate = DEFAULT_RATE;
  char* rate_str = getenv("ADDERROR_RATE");
  if (rate_str) {
    rate = atoi(rate_str);
  }

  return rate;
}


#define DEFAULT_PACKET_SIZE 256 // Packet size in bytes
int get_packet_size()
{
  int packet_size = DEFAULT_PACKET_SIZE;
  char* packet_size_str = getenv("AIRBLUE_PACKET_SIZE");
  if (packet_size_str) {
    packet_size = atoi(packet_size_str);
  }

  return packet_size;
}

#define FTIME_DEFAULT 20000000
unsigned int ftime = 
#ifdef FTIME 
FTIME; 
#else
(unsigned int)-1;
#endif

long long get_finish_cycles()
{
  if (ftime == (unsigned int)-1) {
    char* ftime_str = getenv("ADDERROR_CYCLES");
    long long new_ftime = 0;
    if (ftime_str)
      new_ftime = strtoll(ftime_str,NULL,10);
    if (!new_ftime)
      new_ftime = FTIME_DEFAULT;
    ftime = new_ftime;
  }
  return ftime;
}

// Table of maximum expected bit-errors for various rates/noise levels
// First column is SNR, second is max bit-errors
static long long table[8][8][2] = {
 // Rate 7
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

 // Rate 6
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

 // Rate 5
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

 // Rate 4
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

 // Rate 3
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

 // Rate 2
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

 // Rate 1
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

 // Rate 0
 {
  { 15, 0 },    // 0
  { 13, 100 },  // 81
  { 12, 400 },  // 352
  { 11, 1000 }, // 986
  { 10, 3000 }, // 2894
  { 9,  7400 }, // 7295
  { 8,  18000}, // 16276
  { 7,  30000}  // 26401
 },

};

long long check_ber(long long errors, long long total)
{
  double snr = get_snr();
  int rate = get_rate();
  
  printf("Check errors %llu total %llu\n", errors, total);

  long long max_errors;
  long long table_snr;

  int i = 0;
  do {
    table_snr = table[rate][i][0];
    max_errors = table[rate][i][1];
    ++i;
  } while (i < 8 && snr < table_snr);

  if (errors > max_errors) {
    printf("BER too high! snr=%0.2lf db, expected fewer than %d (at %d db) but was %d\n",
        snr, max_errors, table_snr, errors);

    return 0;
  }

  return 1;
}
