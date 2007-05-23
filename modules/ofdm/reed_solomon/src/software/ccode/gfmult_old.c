/*
  File to test GF multiply algorithm as compared to look up table on GF(256)
*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#define mm  8            /* RS code over GF(2**8) - change to suit */
#define nn  255          /* nn=2**mm -1   length of codeword */
#define tt  16           /* number of errors that can be corrected */
#define kk  223           /* kk = nn-2*tt  */

int pp [mm+1] = { 1, 0, 1, 1, 1, 0, 0, 0, 1} ; /* specify irreducible polynomial coeffts */

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
   { alpha_to[i] = mask ;
     index_of[alpha_to[i]] = i ;
     if (pp[i]!=0)
       alpha_to[mm] ^= mask ;
     mask <<= 1 ;
   }
  index_of[alpha_to[mm]] = mm ;
  mask >>= 1 ;
  for (i=mm+1; i<nn; i++)
   { if (alpha_to[i-1] >= mask)
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
   unsigned int p = 29;
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
	 temp ^= (unsigned int)(p << (k - 8));

   return (temp & 255);
   
}


main()
{

  int *alpha_to = malloc( (nn+1)*sizeof(int) );
  int *index_of = (int*)malloc( (nn+1)*sizeof(int) );

  int i, a, b;

/* generate the Galois Field GF(2**mm) */
  generate_gf(alpha_to, index_of) ;
  printf("Look-up tables for GF(2**%2d)\n",mm) ;
  printf("  i   alpha_to[i]  index_of[i]\n") ;
  for (i=0; i<=nn; i++)
   printf("%3d      %3d          %3d\n",i,alpha_to[i],index_of[i]) ;
  printf("\n\n") ;

  a = 255;
  b = 255;

  printf(" A    B   A*B  Table\n");
  printf("%3d  %3d  %3d   %3d \n", a, b, gfmult_hw(a, b), gfmult_lut(a, b, alpha_to, index_of) ) ;





}

