#include<stdio.h>
#include<stdlib.h>
#include<assert.h>

#define BUFFER_SIZE 16384
#define BLOCK_SIZE 16


void main( int argc, char ** argv) {
  FILE *infile, *outfile; 
  char buf[BUFFER_SIZE];
  int  sample_high, sample_low, buf_count = 0, count, count_expect = 0, error_count = 0, iter; 
  int matches; 
  int bufferHigh[BLOCK_SIZE],bufferLow[BLOCK_SIZE]; 
  int fails = 0;
  int checksum;
  int drops=0,accepts=0;
  int failsMax = 0;
  int blockError = 0;
  int bufferFailure = 0;
  short high,low; 
  infile = stdin;    
  if(argc != 2) {
    printf("Bad args\n");
    exit(0);
  } 


  snprintf(buf,100,"%s_samples_%d.hex",argv[1],buf_count);
  assert(outfile = fopen(buf,"w"));

  //                                s      0     1      2    3     4     5     6     7     8     9     10    11    12    13    14    15    X  e 
  while((matches = (fscanf(infile, "%*s %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %*s",
                    &(bufferHigh[0]),  &(bufferLow[0]), 
                    &(bufferHigh[1]),  &(bufferLow[1]), 
                    &(bufferHigh[2]),  &(bufferLow[2]), 
                    &(bufferHigh[3]),  &(bufferLow[3]), 
                    &(bufferHigh[4]),  &(bufferLow[4]), 
                    &(bufferHigh[5]),  &(bufferLow[5]), 
                    &(bufferHigh[6]),  &(bufferLow[6]), 
                    &(bufferHigh[7]),  &(bufferLow[7]), 
                    &(bufferHigh[8]),  &(bufferLow[8]), 
                    &(bufferHigh[9]),  &(bufferLow[9]), 
                    &(bufferHigh[10]), &(bufferLow[10]), 
                    &(bufferHigh[11]), &(bufferLow[11]), 
                    &(bufferHigh[12]), &(bufferLow[12]), 
                    &(bufferHigh[13]), &(bufferLow[13]), 
                    &(bufferHigh[14]), &(bufferLow[14]), 
                    &(bufferHigh[15]), &(bufferLow[15]), 
                    &checksum, &count))) != EOF) {
    if(matches == 34) {
      //printf("match at: high: %x low: %x \n", sample_high, sample_low);  
      //printf("match at: expected %x got %x\n", count_expect,count);
      if(count_expect != count) {
        if((count == count_expect - 1) || (count == (BUFFER_SIZE-1) && count_expect == 0)) {         
          continue;
	}
        error_count++;
        fails++;
        if(error_count > 30) {  
          printf("error at: checksum %x \n", checksum);  
          printf("error at: expected %x got %x\n", count_expect,count);
          bufferFailure = 1;
        } else {
          continue;
	}
      }

      // Check packet X sum
      for(iter=0;iter < BLOCK_SIZE; iter++) {
        //printf("Checksum %x high %x low %x\n", checksum, bufferHigh[iter], bufferLow[iter]);
        checksum += bufferHigh[iter] + bufferLow[iter];
      }

      if(checksum != 0) {
        //printf("Checksum %x fails: %x\n", count_expect, checksum);
        continue;
      }     
      printf("Got %d %d\n", count_expect, count);
      count_expect = count + 1;
      error_count = 0;
      if(fails > failsMax) {
        failsMax = fails;
      }

      fails = 0;
      // We're all good now, dump stuff to file
      for(iter = 0; iter < BLOCK_SIZE; iter++) {
        high = bufferHigh[iter];
        low = bufferLow[iter];
        //printf("%d %d\n", (int) high, (int) low);
        fprintf(outfile,"%0.8x\n", (bufferHigh[iter] << 16) | (bufferLow[iter] & 0xffff));
      }

      if(count_expect == BUFFER_SIZE/BLOCK_SIZE) {
        count_expect = 0;
        if(!bufferFailure) {          
          buf_count++; 
          accepts++;
        }
        else {
          drops++;
	}
        bufferFailure = 0;
        fclose(outfile);
        snprintf(buf,100,"%s_samples_%d.hex",argv[1],buf_count);
        assert(outfile == fopen(buf,"w"));
      }
    } else {
      printf("No match: %d, %s \n", matches,buf);
      fails++;
      // attempt to find next tail.
      do {
        matches = (fscanf(infile, "%s\n",&buf));
        printf("Got %s\n", buf);
      } while(strcmp("tail",buf) != 0 && matches != EOF);
      continue;
    } 
  }
  printf ("Largest fails: %d, drops %d, accepts %d\n", failsMax,drops,accepts);  
}
