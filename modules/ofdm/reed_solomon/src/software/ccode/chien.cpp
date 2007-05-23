#include <iostream>
#include <iomanip>
#include <fstream>
#include <assert.h>
using namespace std;

// #define mm  4            /* RS code over GF(2**mm) - change to suit */
// #define nn  15          /* nn=2**mm -1   length of codeword */
// #define tt  3           /* number of errors that can be corrected */
// #define kk  9           /* kk = nn-2*tt  */

// int pp [mm+1] = { 1, 1, 0, 0, 1} ; /* specify irreducible polynomial coeffts */

#define mm  8            /* RS code over GF(2**mm) - change to suit */
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
   {  
      alpha_to[i] = mask ;
      index_of[alpha_to[i]] = i ;
      if (pp[i]!=0)
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

unsigned char gfmult_hw (unsigned char a, unsigned char b)
{
   // p[7:0] = 00011101 = 29
   unsigned int p = 29;
   //unsigned int p = 0x3;
   unsigned char k, j, mask1, mask2 ;
   unsigned int temp=0;
   mask2 = 1;

   for (k = 0; k < mm; k++)
   {
      mask1 = 1;
      for (j = 0; j < mm; j++)
      {
	 if (( (a & mask1) >> j ) & ( (b & mask2) >> k ))
	    temp ^= (unsigned int)(1 << (k + j));
	 mask1 = mask1 << 1;
      }
      mask2 = mask2 << 1;
   }
   
   for (k = 2*mm-1; k > mm-1; k--)
      if (temp & (1 << k)) 
	 temp ^= (unsigned int)(p << (k - mm));
   
   return (temp & nn);
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
   unsigned a = 2;
   for (int i = 1; i < n; ++ i)
      a = gfmult_hw (a, 2);
   
   return gfinv_lut( a, alpha_to, index_of );
}
   

// Error Location calculation	
void chien (unsigned char* l, unsigned char* loc, int *alpha_to, int *index_of)
{
   unsigned char lambda_a[tt];
   for (int j = 0; j < tt; ++ j)
   {
      lambda_a [j] = gfmult_hw ( l[j], alpha_inv (((j + 1) * (nn - 1)), alpha_to, index_of));
           cout << "l_a[" << j << " ] = " << (int)lambda_a[j] 
        << " = " << (int)l[j] << " * " 
        << (int) (alpha_inv ((j * (nn - 1)), alpha_to, index_of)) <<  endl;
   }

   for (int i = nn-1; i >= 0; -- i)
   {
      cout << " Calc_E i: " << i << endl;
      loc [i] = 1;
      for (int j = 0; j < tt; ++ j)
	loc [i] ^= lambda_a [j];

      for (int j = 0; j < tt; ++ j)
      {
	 cout << "l_a[" << j << " ] = " << (int) gfmult_hw (lambda_a [j], alpha(j + 1))
	      << " = " << (int)lambda_a [j] << " * " 
              << (int) (alpha (j + 1)) <<  endl;
	 lambda_a [j] = gfmult_hw (lambda_a [j], alpha(j + 1));
      }
   }
}


//---------------------------------------------------
int main (int argc, char* argv [])
{
   ifstream file (argv [1]);
   if (false == file.is_open ())
      return 1;
   
   unsigned char l [1000];
   int i = 0;
   while (false == file.eof ())
   {
      int x;
      file >> x;
      l [i++] = (unsigned char) x;
   }
 	
   int *alpha_to = (int*)malloc( (nn+1)*sizeof(int) );
   int *index_of = (int*)malloc( (nn+2)*sizeof(int) );
   generate_gf(alpha_to, index_of) ;

   unsigned char loc [nn];
   //unsigned char l [tt + 1] = { 1, alpha_to[3], alpha_to[11], alpha_to[9] };
   chien (l, loc, alpha_to, index_of);
   
   for (int i = 0; i < nn; ++ i)
      cout << (int) loc [i] << endl;
   cout << "Error Locations : " << endl;
   for (int i = 0; i < nn; ++ i)
     if (loc [i] == 0) 
        cout << i << endl;

    cout << "Constants for Chien Search : " << endl;
//    cout << "      j          a**(-j*(nn-1)) " << endl;
//    for (int j = 1; j <= tt; ++ j)
//       cout <<"      " << setw (3) << (int) j <<" : return       " 
// 	   << setw (3) << (int)  alpha_inv ((j * (nn - 1)), alpha_to, index_of)
//            << ";" << endl;
   cout << "      j          a**(j) " << endl;
   for (int j = 1; j <= 2*tt; ++ j)
      cout <<"      " << setw (3) << (int) j <<" : return       " 
	   << setw (3) << (int)  alpha (j)
           << ";" << endl;
      
   return 0;
}
