/*
  Incorporates all GF arithmetic used in various modules
*/
#include <iostream>
#include <iomanip>
#include <fstream>
#include <assert.h>
#include "gfarith.h"
using namespace std;
 
void generate_gf( int *alpha_to, int *index_of)
/* generate GF(2**mm) from the irreducible polynomial p(X) in pp[0]..pp[mm]
   lookup tables:  index->polynomial form   alpha_to[] contains j=alpha**i;
                   polynomial form -> index form  index_of[j=alpha**i] = i
   alpha=2 is the primitive element of GF(2**mm)
*/
{
   register int i, mask ;

   mask = 1 ;
   alpha_to[mm] = 0 ;
   for (i=0; i<mm; i++)
   {  
      alpha_to[i] = mask ;
      index_of[alpha_to[i]] = i ;
      if (pp [i] != 0)
	 alpha_to[mm] ^= mask ;
      mask <<= 1 ;
   }
   index_of[alpha_to[mm]] = mm ;
   mask >>= 1 ;
   for (i=mm+1; i<nn; i++)
   { 
      if (alpha_to[i-1] >= mask)
         alpha_to[i] = alpha_to[mm] ^ ((alpha_to[i-1]^mask)<<1) ;
      else alpha_to[i] = alpha_to[i-1]<<1 ;
      index_of[alpha_to[i]] = i ;
   }
   index_of[0] = -1 ;
}


unsigned char gfmult_lut(unsigned char a, unsigned char b, int *alpha_to, int *index_of)
{
   char result = (index_of[a] + index_of[b])%nn;

   return alpha_to[result];

}

unsigned char gfmult_hw(unsigned char a, unsigned char b)
{
   // p[7:0] = 00011101 = 29
   //unsigned int p = 29;
   //unsigned int p = 0x3;
   unsigned char k, j, mask1, mask2 ;
   unsigned int temp = 0;
   mask2 = 1;

   for (k = 0; k < 8; k++)
   {
      mask1 = 1;
      for (j = 0; j < 8; j++)
      {
         if (( (a & mask1) >> j ) & ( (b & mask2) >> k ))
	    temp ^= (unsigned int)(1 << (k + j));
	 mask1 = mask1 << 1;
      }
      mask2 = mask2 << 1;
   }

   for (k = 15; k > 7; k--)
      if (temp & (1 << k)) 
	 temp ^= (unsigned int)(pp_char << (k - 8));

   return (temp & 255);
   
}

unsigned char gfinv_lut(unsigned char a, int *alpha_to, int *index_of)
{
   unsigned char result = (nn - index_of [a])%nn;
   return alpha_to[result];

}

unsigned char alpha (int n)
{
	unsigned a = 2;
	for (int i = 1; i < n; ++ i)
		a = gfmult_hw (a, 2);

	return a;
}

unsigned char alpha_inv (int n, int *alpha_to, int *index_of)
{
   if (n == 0) 
      return 1;
//    unsigned a = 2;
//    for (int i = 1; i < n; ++ i)
//       a = gfmult_hw (a, 2);
   
//    return gfinv_lut( a, alpha_to, index_of );
    return gfinv_lut( alpha (n), alpha_to, index_of );
}

unsigned char gfdiv_lut (unsigned char dividend, unsigned char divisor, int *alpha_to, int *index_of)
{
   return gfmult_hw ( dividend, gfinv_lut(divisor, alpha_to, index_of));
}   


