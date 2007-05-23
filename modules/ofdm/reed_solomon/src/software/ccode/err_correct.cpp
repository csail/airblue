#include <iostream>
#include <fstream>
#include <assert.h>
//#include "gfarith.h"
using namespace std;

// Error Correction    
void err_cor (unsigned char* r, unsigned char* e, unsigned char* d)
{
   for (int i = 0; i < 255; ++ i)
      d [i] <= r [i] ^ e [i]; 
}


//---------------------------------------------------
int main (int argc, char* argv [])
{
   ifstream file1 (argv [1]);
   if (false == file1.is_open ())
      return 1;
   ifstream file2 (argv [2]);
   if (false == file2.is_open ())
      return 1;
   
   unsigned char r [1000];
   int i = 0;
   while (false == file1.eof ())
   {
      int x;
      file1 >> x;
      r [i++] = (unsigned char) x;
   }
   unsigned char e [1000];
   i = 0;
   while (false == file2.eof ())
   {
      int x;
      file2 >> x;
      e [i++] = (unsigned char) x;
   }

}



