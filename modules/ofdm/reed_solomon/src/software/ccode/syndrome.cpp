#include <iostream>
#include <fstream>
#include <assert.h>
#include "gfarith.h"
using namespace std;

// syndrome calculation											
void syndrome (unsigned char* r, unsigned char* s)
{
	// calculate each of the 32 syndromes.
	for (int i = 0; i < 32; ++ i)
	{
		unsigned char a = alpha (i + 1);
		s [i] = 0;
		for (int j = 0; j < 255; ++ j)
		{
			cout << "(" << (int) r [j] << ") " 
			     << (int) a << " : " << (int) s [i] << endl;
			s [i] = gfmult_hw (s [i], a) ^ r [j];
		}
	}
}


//---------------------------------------------------
int main (int argc, char* argv [])
{
	ifstream file (argv [1]);
	if (false == file.is_open ())
		return 1;

	unsigned char r [1000];
	int i = 0;
	while (false == file.eof ())
	{
		int x;
		file >> x;
		r [i++] = (unsigned char) x;
	}
	assert (i >= 255);
	
	unsigned char s [32];
	syndrome (r, s);

	for (int i = 0; i < 32; ++ i)
		cout << (int) s [i] << endl;
}



