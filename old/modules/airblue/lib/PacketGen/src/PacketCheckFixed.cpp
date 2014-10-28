#include "asim/provides/airblue_phy_packet_check.h"

void PrintPacketCheckStats(PACKETCHECKRRR_CLIENT_STUB client) {

  static UINT32 mismatchedPacketsLast, correctPacketsLast, BERHistLast[64], ByteErrLast[4096], firstPass = 0;
  UINT32 mismatchedPackets, correctPackets, BERHist[64], ByteErr[4096];
  

  mismatchedPackets = client->GetMismatchedRX(0);
  correctPackets = client->GetPacketsRXCorrect(0);


  printf("PacketCheck: mismatchedPackets: %d, correctPackets: %d\n",mismatchedPackets, correctPackets);

  for(int i = 0; i < 64;  i++) {
    BERHist[i] = client->GetTotalBER(i);    
    printf("Packets with %d errors: %d\n", i, BERHist[i]);
  }

  for(int i = 0; i < 4096;  i++) {
    ByteErr[i] = client->GetByteBER(i);    
    printf("Byte %d total errors: %d\n", i, ByteErr[i]);
  }

  if(!firstPass) {
    printf("DELTA PacketCheck: mismatchedPackets: %d, correctPackets: %d\n",mismatchedPackets-mismatchedPacketsLast, correctPackets - correctPacketsLast);

    for(int i = 0; i < 64;  i++) {
      printf("DELTA Packets with %d errors: %d\n", i, BERHist[i]-BERHistLast[i]);
    }

    for(int i = 0; i < 4096;  i++) {
      printf("DELTA Byte %d total errors: %d\n", i, ByteErrLast[i]-ByteErr[i]);
    }
  }

 
  mismatchedPacketsLast = mismatchedPackets;
  correctPacketsLast = correctPackets;

  for(int i = 0; i < 64;  i++) {
    BERHistLast[i] = BERHist[i];
  }

  for(int i = 0; i < 4096;  i++) {
    ByteErrLast[i] = ByteErr[i];
  }

  firstPass = 1;
}


