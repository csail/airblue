#include<stdio.h>

#define SCALE_SIZE 4096
#define MIN_VAL 1489
#define MAX_VAL 248

void main() {
  float scales[SCALE_SIZE];
  float factor = .0001;
  float scaleStep = 1.0131;
  int i;

  for(i = SCALE_SIZE - 1; i >= 0; i--) {
    if(i < MAX_VAL) {
      printf("scaleFactors[%d] = 1000.0;\n", i);
    } else if(i > MIN_VAL) {
      printf("scaleFactors[%d] = 0.0;\n", i);
    } else {
      if(factor < 1) {
        printf("scaleFactors[%d] = 0%f;\n", i,factor);
      } else {
        printf("scaleFactors[%d] = %f;\n", i,factor);
      }
      factor = factor * scaleStep;
    }
  }


}

