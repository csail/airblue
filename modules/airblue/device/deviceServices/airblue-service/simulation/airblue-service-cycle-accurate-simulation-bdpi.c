#include <stdio.h>
#include <stdlib.h>

static FILE* inputFile = NULL;
static count;

/* create process and initialize data structures */
unsigned int input_sample()
{
  int i,count;
    printf("main %d: \n",count);
    union {
      int whole;
      short pieces[2];
    } sample;

    if(inputFile == NULL) {
      inputFile = fopen("input.trace","r");
      if(inputFile == NULL) {
        printf("Did not find trace file\n");
        fflush(stdout);
        exit(0);
      }
    }
  
    if(fread(&sample, sizeof(int), 1, inputFile)) {
      //if(count%1000 == 0)
      printf("main %d: %d %d\n",  count, sample.pieces[0]*3, sample.pieces[1]*3);
      count++;      
      sample.pieces[0] = sample.pieces[0]*3; 
      sample.pieces[1] = sample.pieces[1]*3; 
      return sample.whole;      
    } else {
      return 0;    
    }
}
