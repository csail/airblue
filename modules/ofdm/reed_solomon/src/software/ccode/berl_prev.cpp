#include <iostream>
#include <iomanip>
#include <fstream>
#include <assert.h>
using namespace std;

// #define mm  8            /* RS code over GF(2**mm) - change to suit */
// #define nn  255          /* nn=2**mm -1   length of codeword */
// #define tt  16           /* number of errors that can be corrected */
// #define kk  223           /* kk = nn-2*tt  */

// int pp [mm+1] = { 1, 0, 1, 1, 1, 0, 0, 0, 1} ; /* specify irreducible polynomial coeffts */

#define mm  4            /* RS code over GF(2**mm) - change to suit */
#define nn  15          /* nn=2**mm -1   length of codeword */
#define tt  3           /* number of errors that can be corrected */
#define kk  9           /* kk = nn-2*tt  */

int pp [mm+1] = { 1, 1, 0, 0, 1} ; /* specify irreducible polynomial coeffts */

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
   alpha_to[-1] = 0 ;
}


unsigned char gfinv_lut(unsigned char a, int *alpha_to, int *index_of)
{
   unsigned char result = (nn - index_of [a])%nn;
   return alpha_to[result];

}


unsigned char gfmult_hw (unsigned char a, unsigned char b)
{
   // p[7:0] = 00011101 = 29
   //unsigned int p = 29;
   unsigned int p = 0x3;
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

unsigned char gfadd (unsigned char a, unsigned char b)
{
   return a ^ b;
}

unsigned char alpha (int n)
{
   unsigned a = 2;
   for (int i = 1; i < n; ++ i)
      a = gfmult_hw (a, 2);

   return a;
}
   

void shift (unsigned char* reg, unsigned char val)
{
  for (int k = 0; k < 2*tt - 1; ++ k)
    reg [k+1] = reg [k];
  reg [0] = val;
}


// Error locator polynomial calculation											
unsigned char* berl (unsigned char* syn, unsigned char* l, int *alpha_to, int *index_of)
{
   unsigned char L = 0;
   unsigned char *c = (unsigned char*) malloc( (2*tt)*sizeof(unsigned char) );
   unsigned char *p = (unsigned char*) malloc( (2*tt)*sizeof(unsigned char) );
   unsigned char s[2*tt];
   unsigned char *t;

   unsigned char dstar = 1;
   unsigned char d = 0;
   c[0] = 1;
   p[0] = 1;
   s[0] = syn[0]; 

   for (int i = 0; i < 2*tt; ++ i)
   {
      d = 0;
      for (int k = 0; k <= L; ++ k)
      {
 	 d = d ^ gfmult_hw ( c [k], s [i-k]);
	 cout << " c[" << k << "] * s[" << i << " - " << k << "] = " 
	      << (int) gfmult_hw (c [k], s[i-k]) << endl;
      }
      cout << " d [" << (int)i << "] : " << (int)d << endl;
      if ( d == 0)
	shift (p, 0);
      else
      {
	if ( i >= 2*L )
	{
 	   L = i - L + 1;
	   t = c;
	   c = p;
	   p = t;
	   for (int k = 0; k <= i; ++ k)
	      c [k] = p [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), c [k] ); 
	   dstar = gfinv_lut (d, alpha_to, index_of);
	   shift (p, 1);
	}
	else
	{
	   for (int k = 0; k <= i; ++ k)
	      c [k] = c [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), p [k] );
	   shift (p, 0);
	}
      }

      shift (s, syn [i+1]);

      //      cout << "p[" << (int) i << "] = " << (int) p[i] <<  endl;
      
   }
	   
// 	 cout << "(" << (int) r [j] << ") " 
// 	      << (int) a << " : " << (int) s [i] << endl;

   l = c;
   return l;

}

void berl2 (unsigned char* s, unsigned char* c, unsigned char* w, int *alpha_to, int *index_of)
{

   unsigned char L = 0;
   unsigned char *p = (unsigned char*) malloc( (2*tt+1)*sizeof(unsigned char) );
   unsigned char *a = (unsigned char*) malloc( (2*tt+1)*sizeof(unsigned char) );
   //   unsigned char s [2*tt+1];
   unsigned char t [2*tt+1];
   unsigned char t2 [2*tt+1];

   memset (c, 0, (2*tt)*sizeof (unsigned char));
   memset (p, 0, (2*tt)*sizeof (unsigned char));
   memset (w, 0, (2*tt)*sizeof (unsigned char));
   memset (a, 0, (2*tt)*sizeof (unsigned char));
   
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
      cout <<  "  d [" << (int)i << "] : " << (int)d << endl;
      cout << endl << endl;

      if (d == 0)
	 len ++;
      else
      {
	if (i + 1 > 2*L)
	{
	   for (int k = 0; k < 2*tt; ++ k)
	      t [k] = c [k];
	   for (int k = 0; k < 2*tt; ++ k)
	      t2 [k] = w [k];
	   for (int k = len; k <= i + 1; ++ k)
	   {
	      cout << " c[" << k << "] = " 
		   << (int)(c [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), p [k-len] ))
		   << endl;
	      c [k] = c [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), p [k-len] );
	   }
	   for (int k = len; k <= i + 1; ++ k)
	   {
	      cout << " w[" << k << "] = " 
		   << (int)(w [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), a [k-len] ))
		   << endl;
	      w [k] = w [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), a [k-len] );
	   }
	   //	      w [k] = w [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), a [k-len] );
	   L = i - L + 1;

	   for (int k = 0; k < 2*tt; ++k)
	     p [k] = t [k];
	   for (int k = 0; k < 2*tt; ++k)
	     a [k] = t2 [k];
	   dstar = gfinv_lut ( d, alpha_to, index_of );
	   len = 1;
	   cout << "Reset Len -> " << (int)len << endl;
	}
	else
	{
	   for (int k = len; k <= i + 1; ++ k)
	   {
	      cout << " c[" << k << "] = " 
		   << (int)(c [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), p [k-len] ))
		   << " =  " << (int)c [k] << " ^ " << (int) (gfmult_hw( d, dstar ))
		   << " * " << (int)p [k-len] << ". Len = " << (int)len
		   << endl;
	      c [k] = c [k] ^ gfmult_hw ( gfmult_hw( d, dstar ), p [k-len] );
	   }
	   for (int k = len; k <= i + 1; ++ k)
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

//     ifstream file (argv [1]);
//     if (false == file.is_open ())
//        return 1;
  
//     unsigned char s [1000];
//     int i = 0;
//     while (false == file.eof ())
//     {
//        int x;
//        file >> x;
//        s [i++] = (unsigned char) x;
//     }
//     assert (i >= 2*tt);
   
   unsigned char s[] = { 13, 3, 5, 4, 8, 5 };

   unsigned char c [2*tt];
   unsigned char w [2*tt];
   berl2 (s, c, w, alpha_to, index_of);
  
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


