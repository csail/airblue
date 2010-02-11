#define MAX_SIZE 2.1
#define MAX_STEP .0001
#define MAX_ITERS 5
#define MAX_START_NO 2048.0
#define MIN_START_NO (1/512.0)
#define MAX_ERROR .01

void main() {
  int i,j;
  float start;
  for(start = MIN_START_NO; start < MAX_START_NO; start = start *2) {
    float root;
    int first = 0;
    int in_range = 0;

    printf("Start value: %f sucessful over \n", start);
    for(root = MAX_STEP; root < MAX_SIZE; root = root + MAX_STEP) {  
      float u;
      float square = root * root; 
      u = start;
      for(j = 0; j < MAX_ITERS; j++) {
        u = .5 * u * (3-square*u*u);
        // printf("root[%d] %f\n", j+1, u );
      }

      if((1/root/u < (1+MAX_ERROR)) && 
         (1/root/u > (1/(1+MAX_ERROR)))) {
        if(!in_range) {
          printf(" %f-", root );
	} 
        //printf("invroot %f, estimated: %f, delta: %f\n", 1/root, u, 1/root/u);
        in_range = 1;
      } else {
        if(in_range) {
          printf("%f ", root - MAX_STEP);
	} 
        in_range = 0;
      }
    }
    printf("\n");
  }
}
