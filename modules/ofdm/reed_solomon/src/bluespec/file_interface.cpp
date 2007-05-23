#include <iostream>
#include <fstream>
using namespace std;


extern "C"
{
   void loadByteStream (void);
   char getNextStreamByte (void);
   void storeByteStream (void);
   void putNextStreamByte (unsigned char byte);
   void putMACData (unsigned char n, unsigned char t);
   unsigned char isStreamActive (void);
   void closeOutputFile ();
}


ifstream ifs_Input;
ofstream ofs_Output;


//---------------------------------------------------------------------
void loadByteStream (void)
{
   cout << "  reading from file '" << DATA_FILE_PATH << "'" << endl;
   ifs_Input.open (DATA_FILE_PATH);
   if (false == ifs_Input.is_open ())
      cout << "[ERROR]  failed to open input file." << endl;
}


//---------------------------------------------------------------------
char getNextStreamByte (void)
{
   int byte;
   ifs_Input >> byte;

   if (true == ifs_Input.eof ())
      cout << "  end of file reached." << endl;

   return (unsigned char) byte;
}


//---------------------------------------------------------------------
void storeByteStream (void)
{
   cout << "  writing to file '" << OUT_DATA_FILE_PATH << "'" << endl;
   ofs_Output.open (OUT_DATA_FILE_PATH);
   if (false == ofs_Output.is_open ())
      cout << "[ERROR]  failed to open output file." << endl;
}


//---------------------------------------------------------------------
void putNextStreamByte (unsigned char byte)
{
   ofs_Output << (int) byte << endl;
}


//---------------------------------------------------------------------
void putMACData (unsigned char n, unsigned char t)
{
   ofs_Output << (int) n << ' ' << (int)t << endl;
}


//---------------------------------------------------------------------
unsigned char isStreamActive (void)
{
   return ((true == ifs_Input.is_open ()) && (false == ifs_Input.eof ()));
}


//---------------------------------------------------------------------
void closeOutputFile ()
{
   ofs_Output.flush ();
   ofs_Output.close ();
}
