#include <iostream>
#include <iomanip>
#include <fstream>
#include <assert.h>
#include "gfarith.h"
using namespace std;
 
void shift (unsigned char* reg, unsigned char val)
{
  for (int k = 0; k < 2*tt - 1; ++ k)
    reg [k+1] = reg [k];
  reg [0] = val;
}

void berl (unsigned char* s, unsigned char* c, unsigned char* w, int *alpha_to, int *index_of)
{

   unsigned char L = 0;
   unsigned char *p = (unsigned char*) malloc ((2*tt+1)*sizeof(unsigned char));
   unsigned char *a = (unsigned char*) malloc ((2*tt+1)*sizeof(unsigned char));
   //   unsigned char s [2*tt+1];
   unsigned char t [2*tt+1];
   unsigned char t2 [2*tt+1];

   memset (c, 0, (tt + 1)*sizeof (unsigned char));
   memset (p, 0, (tt + 1)*sizeof (unsigned char));
   memset (w, 0, (tt + 1)*sizeof (unsigned char));
   memset (a, 0, (tt + 1)*sizeof (unsigned char));
   
   //for (int k = 0; k < 2*tt; ++k)
   //  s [k+1] = syn [k];

   unsigned char dstar = 1;
   unsigned char d = 0;
   c[0] = 1;
   p[0] = 1;
   w[0] = 0;
   a[0] = 1;
   unsigned char len = 1;

   for (int i = 0; i < 2*tt; i++ )
   {
      d = s[i];
      for (int k = 0; k < L; k++)
      {
         cout << "     d = d(" << (int)d 
               << ") ^ mul (c[k(" << k << ")+1](" << (int)c [k+1] << "), "
               << "s [i(" << i << ") - k(" << k << ") -1](" << (int)s[i-k-1] << ")"
               << endl;
         d = d ^ gfmult_hw (c [k+1], s [i-k-1]);
      }
      cout << endl << endl;
      cout <<  "d [" << (int)i << "] : " << (int)d << endl;

      if (d == 0)
         len ++;
      else
      {
         cout << "i (" << i << ") + 1 > 2*L (" << (int)L << ")" << endl;
         if (i + 1 > 2*L)
         {
            for (int k = 0; k < 2*tt; ++ k)
            {
               t [k] = c [k];
               t2 [k] = w [k];
            }
            for (int k = len; k <= L + 2; ++ k)
            {
               cout << " c[" << k << "] (" 
                    << (int)(c [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), p [k-len] ))
                    << ")  =  c[" << k << "] (" << (int)c[k] 
                    << ")  ^  d_d* (" << (int) (gfmult_hw (d, dstar))
                    << ") * p[" << k-len << "] (" << (int)p [k-len] << "). Len = " << (int)len
                    << endl;
               c [k] = c [k] ^ gfmult_hw (gfmult_hw (d, dstar), p [k-len] );
            }
            for (int k = len; k <= L + 1; ++ k)
            {
               cout << " w[" << k << "] = " 
               << (int)(w [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), a [k-len] ))
               << endl;
               w [k] = w [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), a [k-len] );
            }
            //	      w [k] = w [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), a [k-len] );
            L = i - L + 1;

            for (int k = 0; k <= tt; ++k)
            {
               p [k] = t [k];
               a [k] = t2 [k];
            }
            dstar = gfinv_lut ( d, alpha_to, index_of );
            len = 1;
            cout << "Reset Len -> " << (int)len << endl;
         }
         else
         {
            for (int k = len; k <= L + 1; ++ k)
            {
               cout << " c[" << k << "] (" 
                    << (int)(c [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), p [k-len] ))
                    << ")  =  c[" << k << "] (" << (int)c[k] 
                    << ")  ^  d_d* (" << (int) (gfmult_hw (d, dstar))
                    << ") * p[" << k-len << "] (" << (int)p [k-len] << "). Len = " << (int)len
                    << endl;
               c [k] = c [k] ^ gfmult_hw (gfmult_hw (d, dstar), p [k-len] );
            }
            for (int k = len; k <= L + 1; ++ k)
               w [k] = w [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), a [k-len] );
            len ++;
            cout << "Inc Len -> " << (int)len << endl;
         }
      }

      cout << "c(x) = ";
      for (int k = 0; k <= tt; ++k)
         cout << (int) c[k] << ' ';
      cout << endl;
      cout << "L = " << (int) L << endl;
      cout << "p(x) = ";
      for (int k = 0; k <= tt; ++k)
         cout << (int) p[k] << ' ';
      cout << endl;
      cout << "l = " << (int) len << endl;
      
      cout << "w(x) = ";
      for (int k = 0; k <= tt; ++k)
         cout << (int) w[k] << ' ';
      cout << endl;
      cout << "a(x) = ";
      for (int k = 0; k <= tt; ++k)
         cout << (int) a[k] << ' ';
      cout << endl;

   }
}


//---------------------------------------------------
int main (int argc, char* argv [])
{
   int *alpha_to = (int*)malloc( (nn+1)*sizeof(int) );
   int *index_of = (int*)malloc( (nn+2)*sizeof(int) );
   generate_gf(alpha_to, index_of) ;

    ifstream file (argv [1]);
    if (false == file.is_open ())
       return 1;
  
    unsigned char s [1000];
    int i = 0;
    while (false == file.eof ())
    {
       int x;
       file >> x;
       s [i++] = (unsigned char) x;
    }
   
    //unsigned char s[] = { 13, 3, 5, 4, 8, 5 };

   unsigned char c [tt+1];
   unsigned char w [tt+1];
   berl (s, c, w, alpha_to, index_of);
  
   cout << "l in index form" << endl;
   cout << "---------------------" << endl;
   for (int i = 1; i < tt+1; ++ i)
      cout << (int) index_of [c[i]] << endl;

   cout << "l in polynomial form" << endl;
   cout << "---------------------" << endl;
   for (int i = 1; i < tt+1; ++ i)
      cout << (int) c[i] << endl;

   cout << "w in index form" << endl;
   cout << "---------------------" << endl;
   for (int i = 1; i < tt+1; ++ i)
      cout << (int) index_of [w[i]] << endl;

   cout << "w in polynomial form" << endl;
   cout << "---------------------" << endl;
   for (int i = 1; i < tt+1; ++ i)
      cout << (int) w[i] << endl;


   //   for (int i = 0; i < nn + 1; ++ i)
   //cout <<"      " << setw (3) << (int) i <<" : return       " << setw (3) << (int) gfinv_lut (i, alpha_to, index_of) << ";" <<endl;
   return 0;
}


