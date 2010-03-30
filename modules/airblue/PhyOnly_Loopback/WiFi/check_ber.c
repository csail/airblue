#include <stdlib.h>
#include <stdio.h>

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
    rate = strtod(rate_str, NULL);
  }

  return rate;
}

// Table of maximum expected bit-errors for various rates/noise levels
// First column is SNR, second is max bit-errors
static int table[8][8][2] = {
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

int check_ber(int errors)
{
  double snr = get_snr();
  int rate = get_rate();
  
  int max_errors;
  int table_snr;

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
