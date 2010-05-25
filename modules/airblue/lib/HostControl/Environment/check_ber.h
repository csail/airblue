#ifndef CHECK_BER
#define CHECK_BER

int get_rate();
int get_packet_size();
long long get_finish_cycles();
long long check_ber(long long errors, long long total);

#endif
