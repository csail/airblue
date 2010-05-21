#ifndef CHECK_BER
#define CHECK_BER

int get_rate();
int get_packet_size();
unsigned int get_finish_cycles();
int check_ber(int errors, int total);

#endif
