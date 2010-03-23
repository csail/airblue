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

// Table of maximum expected bit-errors
// First column is SNR, second is max bit-errors
static int table[5][2] = {
 { 15, 0 },    // 0
 { 12, 400 },  // 352
 { 11, 1000 }, // 986
 { 10, 3000 }, // 2894
 { 7,  30000}  // 26401
};

int check_ber(int errors)
{
  double snr = get_snr();
  
  int max_errors = 0;
  int i;
  for (i = 0; i < 5; i++) {
    if (snr > table[i][0]) 
      break;
    max_errors = table[i][1];
  }

  if (errors > max_errors) {
    printf("BER too high! snr=%lf, expected fewer than %d but was %d\n", snr,
        max_errors, errors);

    return 0;
  }

  return 1;
}
