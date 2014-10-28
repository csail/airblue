#include<stdio.h>


int main() {
  int hex, count=0;
  while(scanf("%x",&hex)!=EOF) {
    short img =  hex & 0xffff;
    short rel = (hex >> 16) & 0xffff;
    printf("%d %d %d\n", count, rel, img);
    count++;
  }
}
