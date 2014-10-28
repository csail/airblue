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

#ifndef __PACKETDISSECTORS_H__
#define __PACKETDISSECTORS_H__

//#include "config.h"

#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif
#ifdef HAVE_INTTYPES_H
#include <inttypes.h>
#endif

#include <vector>
#include <string>
#include <map>

//#include "globalregistry.h"
//#include "kis_netframe.h"
//#include "packetchain.h"
#include "packet.h"
#include "macaddr.h"
#include "util.h"

/*
 * Basic built-in Kismet dissectors that handle ieee80211 dissection and
 * data dissection.  This should be instantiated from main() and left alone
 * for the most part, we're just wrapped in a class so that we can easily track
 * our alert references and so that main() isn't making a pile of random 
 * links
 */

// Protocol stuff
enum WEPKEY_fields {
    WEPKEY_origin, WEPKEY_bssid, WEPKEY_key, WEPKEY_decrypted, WEPKEY_failed
};

// Strings protocol
enum STRINGS_fields {
	STRINGS_bssid, STRINGS_source, STRINGS_dest, STRINGS_string,
	STRINGS_maxfield
};
typedef struct {
        std::string text;
	mac_addr bssid;
	mac_addr source;
	mac_addr dest;
} string_proto_info;


// String reference
class kis_string_info : public packet_component {
public:
	kis_string_info() {
	  self_destruct = 1;
	}

	std::vector<std::string> extracted_strings;
};

// Wep keys
typedef struct {
    int fragile;
    mac_addr bssid;
    unsigned char key[25];
    unsigned int len;
    unsigned int decrypted;
    unsigned int failed;
} wep_key_info;

class KisBuiltinDissector {
public:
	KisBuiltinDissector();
	//	KisBuiltinDissector(GlobalRegistry *in_globalreg);
	~KisBuiltinDissector();

	int ieee80211_dissector(kis_packet *in_pack);
	//int basicdata_dissector(kis_packet *in_pack);
	//int basicstring_dissector(kis_packet *in_pack);

	//int wep_data_decryptor(kis_packet *in_pack);
	//int wep_data_mangler(kis_packet *in_pack);

	int GetIEEETagOffsets(unsigned int init_offset, kis_datachunk *in_chunk,
			      std::map<int, std::vector<int> > *tag_cache_map);

	//int WPACipherConv(uint8_t cipher_index);
	//int WPAKeyMgtConv(uint8_t mgt_index);

	//void SetStringExtract(int in_extr);

	//void AddWepKey(mac_addr bssid, uint8_t *key, unsigned int len, int temp);

	//void BlitKeys(int in_fd);

	// Transform an encrypted chunk into a plaintext chunk, abstracted for use
	// by other components
	//static kis_datachunk *DecryptWEP(kis_ieee80211_packinfo *in_packinfo,
	//								 kis_datachunk *in_chunk, 
	//								 unsigned char *in_key, int in_key_len,
	//								 unsigned char *in_id);

protected:
	
	int netstumbler_aref;
	int nullproberesp_aref;
	int lucenttest_aref;
	int msfbcomssid_aref;
	int msfdlinkrate_aref;
	int msfnetgearbeacon_aref;
	int longssid_aref;
	int disconcodeinvalid_aref;
	int deauthcodeinvalid_aref;
	int dhcp_clientid_aref;

	int client_wepkey_allowed;

	int dissect_data;

	int listwepkey_cmdid;
	int addwepkey_cmdid;
	int delwepkey_cmdid;
	int strings_cmdid;
	int stringsfilter_cmdid;

	int blit_time_id;

	unsigned char wep_identity[256];
};

#endif

