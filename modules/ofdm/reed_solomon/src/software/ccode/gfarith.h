/*
  File to test GF multiply algorithm as compared to look up table on GF(256)
*/

#define mm  8            /* RS code over GF(2**8) - change to suit */
#define nn  255          /* nn=2**mm -1   length of codeword */
#define tt  13           /* number of errors that can be corrected */
#define kk  229           /* kk = nn-2*tt  */

const unsigned int pp [mm+1] = { 1, 0, 1, 1, 1, 0, 0, 0, 1} ; /* specify irreducible polynomial coeffts */
//#define pp [mm+1] = { 1, 0, 1, 1, 1, 0, 0, 0, 1}  /* specify irreducible polynomial coeffts */
// pp[7:0] = 00011101 = 29
//unsigned int pp_char = 29;
const unsigned char pp_char = 29;
 
void generate_gf( int *alpha_to, int *index_of);
unsigned char gfmult_lut(unsigned char a, unsigned char b, int *alpha_to, int *index_of);
unsigned char gfmult_hw(unsigned char a, unsigned char b);
unsigned char gfinv_lut(unsigned char a, int *alpha_to, int *index_of);
unsigned char alpha (int n);
unsigned char alpha_inv (int n, int *alpha_to, int *index_of);
unsigned char gfdiv_lut (unsigned char dividend, unsigned char divisor, int *alpha_to, int *index_of);



