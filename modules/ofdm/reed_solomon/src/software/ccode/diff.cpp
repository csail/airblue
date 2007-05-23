#include <iostream>
#include <fstream>
using namespace std;


int main (int argc, char* argv [])
{
	if (argc < 3)
	{
		cout << "Please give the names of the files to compare." << endl;
		return 0;
	}

	ifstream file_left (argv [1]);
	ifstream file_right (argv [2]);

	while ((false == file_left.eof ()) &&
		(false == file_right.eof ()))
	{
		char chLeft;
		char chRight;

		file_left >> chLeft;
		file_right >> chRight;

		if (chLeft != chRight)
			cout << dec << chLeft << " != " << chRight << endl;
	}

	return 0;
}
