/*
    This file is part of Kismet

    Kismet is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Kismet is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Kismet; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef __KIS_UTIL_H__
#define __KIS_UTIL_H__

//#include "config.h"

#include <stdio.h>
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif
#ifdef HAVE_INTTYPES_H
#include <inttypes.h>
#endif
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <pwd.h>
#include <ctype.h>
#include <math.h>
#include <glib.h>
#include <string>
#include <map>
#include <vector>
#include <list>
#include <sstream>
#include <iomanip>

// ieee float struct for a 64bit float for serialization
typedef struct {
	guint64 mantissa:52 __attribute__ ((packed));
	guint64 exponent:11 __attribute__ ((packed));
	guint64 sign:1 __attribute__ ((packed));
} ieee_64_float_t;

typedef struct {
	unsigned int mantissal:32;
	unsigned int mantissah:20;
	unsigned int exponent:11;
	unsigned int sign:1;
} ieee_double_t;

typedef struct {
	unsigned int mantissal:32;
	unsigned int mantissah:32;
	unsigned int exponent:15;
	unsigned int sign:1;
	unsigned int empty:16;
} ieee_long_double_t;

// Munge a std::string to characters safe for calling in a shell
void MungeToShell(char *in_data, int max);
std::string MungeToShell(std::string in_data);
std::string MungeToPrintable(const char *in_data, int max, int nullterm);
std::string MungeToPrintable(std::string in_str);
std::string StrLower(std::string in_str);
std::string StrUpper(std::string in_str);
std::string StrStrip(std::string in_str);
std::string StrPrintable(std::string in_str);
std::string AlignString(std::string in_txt, char in_spacer, int in_align, int in_width);

int HexStrToUint8(std::string in_str, guint8 *in_buf, int in_buflen);
std::string HexStrFromUint8(gint8 *in_buf, int in_buflen);

template<class t> class NtoString {
public:
	NtoString(t in_n, int in_precision = 0, int in_hex = 0) { 
	  std::ostringstream osstr;

		if (in_hex)
		  osstr << std::hex;

		if (in_precision)
		  osstr << std::setprecision(in_precision) << std::fixed;

		osstr << in_n;

		s = osstr.str();
	}

	std::string Str() { return s; }

	std::string s;
};

#define IntToString(I)			NtoString<int>((I)).Str()
#define HexIntToString(I)		NtoString<int>((I), 0, 1).Str()
#define LongIntToString(L)		NtoString<long int>((L)).Str()

void SubtractTimeval(struct timeval *in_tv1, struct timeval *in_tv2,
					 struct timeval *out_tv);

// Generic options pair
struct opt_pair {
	std::string opt;
	std::string val;
	int quoted;
};

// Generic option handlers
std::string FetchOpt(std::string in_key, std::vector<opt_pair> *in_vec);
std::vector<std::string> FetchOptVec(std::string in_key, std::vector<opt_pair> *in_vec);
int StringToOpts(std::string in_line, std::string in_sep, std::vector<opt_pair> *in_vec);
void AddOptToOpts(std::string opt, std::string val, std::vector<opt_pair> *in_vec);
void ReplaceAllOpts(std::string opt, std::string val, std::vector<opt_pair> *in_vec);

int XtoI(char x);
int Hex2UChar(unsigned char *in_hex, unsigned char *in_chr);

std::vector<std::string> StrTokenize(std::string in_str, std::string in_split, int return_partial = 1);

// 'smart' tokenizeing with start/end positions
struct smart_word_token {
    std::string word;
    size_t begin;
    size_t end;

    smart_word_token& operator= (const smart_word_token& op) {
        word = op.word;
        begin = op.begin;
        end = op.end;
        return *this;
    }
};

std::vector<smart_word_token> BaseStrTokenize(std::string in_str, 
										 std::string in_split, std::string in_quote);
std::vector<smart_word_token> NetStrTokenize(std::string in_str, std::string in_split, 
										int return_partial = 1);

// Simplified quoted std::string tokenizer, expects " ' to start at the beginning
// of the token, no abc"def ghi"
std::vector<std::string> QuoteStrTokenize(std::string in_str, std::string in_split);

int TokenNullJoin(std::string *ret_str, const char **in_list);

std::string InLineWrap(std::string in_txt, unsigned int in_hdr_len,
				  unsigned int in_max_len);
std::vector<std::string> LineWrap(std::string in_txt, unsigned int in_hdr_len, 
						unsigned int in_maxlen);
std::vector<int> Str2IntVec(std::string in_text);

int IsBlank(const char *s);

// Clean up XML and CSV data for output
std::string SanitizeXML(std::string);
std::string SanitizeCSV(std::string);

void Float2Pair(float in_float, int16_t *primary, int64_t *mantissa);
float Pair2Float(int16_t primary, int64_t mantissa);

// Convert a standard channel to a frequency
int ChanToFreq(int in_chan);
int FreqToChan(int in_freq);

// Convert an IEEE beacon rate to an integer # of beacons per second
unsigned int Ieee80211Interval2NSecs(int in_rate);

// Run a system command and return the error code.  Caller is responsible 
// for security.  Does not fork out
int RunSysCmd(char *in_cmd);

// Fork and exec a syscmd, return the pid of the new process
pid_t ExecSysCmd(char *in_cmd);

#ifdef SYS_LINUX
int FetchSysLoadAvg(guint8 *in_avgmaj, guint8 *in_avgmin);
#endif

// Adler-32 checksum, derived from rsync, adler-32
guint32 Adler32Checksum(const char *buf1, int len);

// 802.11 checksum functions, derived from the BBN USRP 802.11 code
#define IEEE_802_3_CRC32_POLY	0xEDB88320
unsigned int update_crc32_80211(unsigned int crc, const unsigned char *data,
								int len, unsigned int poly);
void crc32_init_table_80211(unsigned int *crc32_table);
unsigned int crc32_le_80211(unsigned int *crc32_table, const unsigned char *buf, 
							int len);


// Proftpd process title manipulation functions
void init_proc_title(int argc, char *argv[], char *envp[]);
void set_proc_title(const char *fmt, ...);

// Simple lexer for "advanced" filter stuff and other tools
#define _kis_lex_none			0
#define _kis_lex_string			1
#define _kis_lex_quotestring	2
#define _kis_lex_popen			3
#define _kis_lex_pclose			4
#define _kis_lex_negate			5
#define _kis_lex_delim			6

typedef struct {
	int type;
	std::string data;
} _kis_lex_rec;

std::list<_kis_lex_rec> LexString(std::string in_line, std::string& errstr);

#define LAT_CONVERSION_FACTOR 10000000
#define LON_CONVERSION_FACTOR 10000000
#define ALT_CONVERSION_FACTOR 1000
guint32 lat_to_uint32(double lat);
guint32 lon_to_uint32(double lat);
guint32 alt_to_uint32(double alt);

double lat_to_double(guint32 lat);
double lon_to_double(guint32 lon);
double alt_to_double(guint32 lon);

#endif

