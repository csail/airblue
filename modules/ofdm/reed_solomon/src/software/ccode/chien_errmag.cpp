#include <iostream>
#include <iomanip>
#include <fstream>
#include <assert.h>
#include "gfarith.h"
using namespace std;

// Error Location calculation	     
void chien_search (unsigned char* l, unsigned char* loc, int *alpha_to, int *index_of)
{
   unsigned char lambda_a [tt];
   for (int j = 1; j <= tt; ++ j)
      lambda_a [j] = gfmult_hw ( l[j-1], alpha_inv ((j * (nn - 1)), alpha_to, index_of));

   for (int i = nn-1; i >= 0; -- i)
   {
      loc [i] = 1;
      for (int j = 1; j <= tt; ++ j)
	loc [i] ^= lambda_a [j];

      for (int j = 1; j <= tt; ++ j)
	 lambda_a [j] = gfmult_hw (lambda_a [j], alpha(j));
   }
}
  
// Assumption: First bit of Lambda (alpha**0) is not transmitted
void compute_deriv (unsigned char* lambda, unsigned char*  lambda_deriv, unsigned char length)
{
   memset (lambda_deriv, 0, (length)*sizeof (unsigned char));
   for (int i = 0; i < length; i = i + 2)
     lambda_deriv [i] = lambda [i];
}

unsigned char poly_eval (unsigned char* poly, unsigned char length, unsigned char alpha)
{
   unsigned char val = 0;
   for (int j = 0; j < length; ++ j)
   {
      val = gfmult_hw (val, alpha) ^ poly [length - j - 1];
   }
   return val;

}

// Error Correction Vector generation
void chien_errmag (unsigned char* lambda, unsigned char* omega, unsigned char* err, int *alpha_to, int *index_of)
{
   unsigned char loc [nn];
   unsigned char lambda_deriv [tt];

   chien_search (lambda, loc, alpha_to, index_of);
   compute_deriv (lambda, lambda_deriv, tt);
   
   unsigned char omega_val = 0;
   unsigned char lambda_der_val = 0;
   
	for (int j = nn - 1; j >= 0; -- j)
	{
		if (loc [j] == 0)
		{
			cout << "omega (" << j << ") = ";
			omega_val = poly_eval (omega, tt, alpha_inv (j, alpha_to, index_of));
			cout << (int) (unsigned char) omega_val << endl;
			cout << "lambda (" << j << ") = ";
			lambda_der_val = poly_eval (lambda_deriv, tt, alpha_inv (j, alpha_to, index_of));
			cout << (int) (unsigned char) lambda_der_val << endl;
			err [j] = gfdiv_lut (omega_val, lambda_der_val, alpha_to, index_of);
		}
		else
			err [j] = 0;
	}
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
   ifstream file3 (argv [3]);
   if (false == file3.is_open ())
      return 1;
   
   unsigned char l [1000];
   int i = 0;
   while (false == file1.eof ())
   {
      int x;
      file1 >> x;
      l [i++] = (unsigned char) x;
   }
   unsigned char w [1000];
   i = 0;
   while (false == file2.eof ())
   {
      int x;
      file2 >> x;
      w [i++] = (unsigned char) x;
   }

   unsigned char r [1000];
   i = 0;
   while (false == file3.eof ())
   {
      int x;
      file3 >> x;
      r [i++] = (unsigned char) x;
   }
 	
   int *alpha_to = (int*)malloc( (nn+1)*sizeof(int) );
   int *index_of = (int*)malloc( (nn+2)*sizeof(int) );
   generate_gf(alpha_to, index_of) ;

   unsigned char err [nn];
   //unsigned char l [tt] = {alpha_to [3], alpha_to [11], alpha_to [9]};
   //unsigned char w [tt] = {alpha_to [13], alpha_to [0], alpha_to [2]};
   chien_errmag (l, w, err, alpha_to, index_of);
   
   cout << "i   err[index]  err[poly]" << endl;     
   for (int i = 0; i < nn; ++ i)
     cout << setw(3) << i << "     " 
	  << setw(3) << (int) index_of [err [i]] << "      " 
	  <<  setw(3) << (int) err [i] << endl;

   cout << "i   r[i]   e[i]   d[i]" << endl;     
   for (int i = 0; i < nn; ++ i)
     cout << setw(3) << i 
	  << setw(6) << (int)  r [nn - i - 1] 
	  << setw(6) << (int)  err [i]
	  << setw(6) << (int) (r [nn - i - 1] ^ err [i]) << endl;
 
//    cout << "Computing alpha_inv constants for ErrMagComp" << endl;     
//    cout << "      j          a**(-j) " << endl;
//    for (int j = 1; j <= nn; ++ j)
//       cout <<"      " << setw (3) << (int) j <<" : return       " 
//  << setw (3) << (int)  alpha_inv ( j, alpha_to, index_of)
//            << ";" << endl;
 

 
//    cout << "Elaborating GF_multiplier" << endl;     
//    for (int i = 0; i < 8; i = i + 1)
//       for (int j = 0; j < 8; j = j + 1)
// 	cout << "   result [" << i + j << "] = result [" << i + j << "] ^ (left [" << j << "] & right [" << i << "]);" << endl;

//    for (int i = 15; i > 7; i = i - 1)
//    {
//       cout << "   if (result [" << i << "] == 1'b1)" << endl;
//       cout << "      result = result ^ ((zeroExtend (primitive_polynomial)) << (" << i - 8 << "));" << endl;
//    }


   return 0;
   
}



