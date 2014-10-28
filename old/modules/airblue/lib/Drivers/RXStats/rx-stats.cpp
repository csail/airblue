#include <stdio.h>
#include <time.h>

#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_driver_application.h"
#include "asim/provides/airblue_environment.h"
#include "asim/provides/clocks_device.h"
#include "asim/provides/clocks_device.h"
#include "asim/provides/airblue_phy_packet_check.h"

using namespace std;

double timespecdiff(timespec start, timespec end)
{
  timespec temp;
  if ((end.tv_nsec-start.tv_nsec)<0) {
    temp.tv_sec = end.tv_sec-start.tv_sec-1;
    temp.tv_nsec = 1000000000+end.tv_nsec-start.tv_nsec;
  } else {
    temp.tv_sec = end.tv_sec-start.tv_sec;
    temp.tv_nsec = end.tv_nsec-start.tv_nsec;
  }
  return (double)temp.tv_sec + (double) .000000001 * temp.tv_nsec;
}

 
// constructor
AIRBLUE_DRIVER_CLASS::AIRBLUE_DRIVER_CLASS(PLATFORMS_MODULE p) :
    DRIVER_MODULE_CLASS(p)
{
  sataStub = new SATARRR_CLIENT_STUB_CLASS(p);
  packetCheckStub = new PACKETCHECKRRR_CLIENT_STUB_CLASS(p); 
  packetGenStub = new PACKETGENRRR_CLIENT_STUB_CLASS(p); 
}

// destructor
AIRBLUE_DRIVER_CLASS::~AIRBLUE_DRIVER_CLASS()
{
}

// init
void
AIRBLUE_DRIVER_CLASS::Init()
{
}

// main
void
AIRBLUE_DRIVER_CLASS::Main()
{

  UINT8 packet_no_last = 0;
  UINT32 sample_dropped_last = 0, sample_dropped; // dropping samples is an error condition
  UINT32 ber = 0, result = 0, correct = 0, bytes = 0, crc = 0;
  UINT32 ber_last = 0, result_last = 0, correct_last = 0, bytes_last = 0, crc_last = 0;
  UINT32 hintTotal = 0, countTotal = 0, hintRst = 0;
  timespec time_last, time_current;
  bool first = true; 
  UINT64 realignRaw ;
  UINT32 realign;
  UINT32 odds;                     
     
  printf("Enabling packet generation\n");
  while(1) {
    realignRaw = sataStub->GetRealign(0);
    realign = realignRaw & 0xffffffff;
    //UINT resets = (realignRaw >> 32) & 0xffff;
    odds = (realignRaw >> 32) & 0xffffffff;

    ber_last = ber;
    crc_last = crc;
    result_last = result;
    correct_last = correct;
    bytes_last = bytes;
    ber = packetCheckStub->GetBER(0);
    result = packetCheckStub->GetPacketsRX(0);    
    correct = packetCheckStub->GetPacketsRXCorrect(0);    
    bytes = packetCheckStub->GetBytesRXCorrect(0);    
    crc = packetCheckStub->GetPassedCRC(0); 
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time_current);

    if(!first) {
      printf("PacketCheck:Correct:%d:Bytes:%d:PacketDelta:%d:CorrectDelta:%d:CRCDelta:%d:BytesCorrectDelta:%d:BER:%f:PER:%f:Time:%f\n", 
           correct,
           bytes,
           result - result_last,
	   correct - correct_last,
           crc - crc_last,
           bytes - bytes_last,
           (float)(ber - ber_last)/(float)(bytes - bytes_last)/8,
           1 - (float)(correct - correct_last)/(float)(result - result_last),
	   timespecdiff(time_last,time_current)
          );
      }
      else {
	//        printf("Length:%d:%d\n",ber_raw.length,ber_raw.packet_no);
      }

    sample_dropped = sataStub->GetSampleDropped(0);

    if(sample_dropped != sample_dropped_last) {
      printf("RX:%lluTX:%d Sent: %llu Dropped: %d Realign: %d Odd: %d errors: %d \n", sataStub->GetRXCount(0), sataStub->GetTXCount(0), sataStub->GetSampleSent(0), sataStub->GetSampleDropped(0), realign,  odds, sataStub->GetRXErrors(0));
    }

    sample_dropped_last = sample_dropped;

    time_last = time_current;      
    sleep(3);
    first = 0;

  }

}

// register driver
static RegisterDriver<AIRBLUE_DRIVER_CLASS> X;
