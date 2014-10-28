#include "asim/provides/virtual_platform.h"
#include "asim/provides/connected_application.h"
#include "asim/provides/airblue_convolutional_decoder_backend.h"
#include "asim/provides/airblue_host_control.h"
#include "asim/provides/airblue_channel.h"
#include "asim/rrr/client_stub_SOFTWAREHOSTCONTROLRRR.h"

using namespace std;

class AIRBLUE_RATE_DRIVER_CLASS : public DRIVER_MODULE_CLASS
{
  private:
    SOFTWAREHOSTCONTROLRRR_CLIENT_STUB clientStub;
    
    double GetHint();

  public:
    AIRBLUE_RATE_DRIVER_CLASS(PLATFORMS_MODULE p);

    // init
    void Init();

    void Main();
};

AIRBLUE_RATE_DRIVER_CLASS::AIRBLUE_RATE_DRIVER_CLASS(PLATFORMS_MODULE p) :
    DRIVER_MODULE_CLASS(p)
{
    clientStub = new SOFTWAREHOSTCONTROLRRR_CLIENT_STUB_CLASS(p);
}

void
AIRBLUE_RATE_DRIVER_CLASS::Init()
{
}

double
AIRBLUE_RATE_DRIVER_CLASS::GetHint()
{
    INT32 hint = clientStub->GetPacketHint();
    return ((double) hint) / (1 << 16);
}

int choose_rate(int current, double pred)
{
    switch (current) {
        case 0:
            if (pred <= -32)
                return 2;
            return 0;
        case 2:
            if (pred > -14)
                return 0;
            if (pred <= -45)
                return 4;
            return 2;
        case 4:
            if (pred > -14)
                return 2;
            return 4;
    }
    return current;
}

int choose_rate_viterbi(int current, double pred)
{
    switch (current) {
        case 0:
            if (pred < -21)
                return 2;
            return 0;
        case 2:
            if (pred > -13)
                return 0;
            if (pred < -29)
                return 4;
            return 2;
        case 4:
            if (pred > -13)
                return 2;
            return 4;
    }
    return current;
}


void
AIRBLUE_RATE_DRIVER_CLASS::Main()
{
    channel* ch = CHANNEL_RRR_SERVER_CLASS::GetInstance()->GetChannel();

    int PACKETS = 1000000;
    int rate = 2;

    for (int i = 0; i < PACKETS; i++) {
        void *start_state = ch->copy_state();

        clientStub->SetRate(rate);
        clientStub->SetPacketSize(6);

        UINT64 errors = clientStub->GetErrors();
        UINT64 total = clientStub->GetTotalBits();
        double hint = GetHint();

        const char *status = "OK";
        if (errors > 0) {
            if (rate > 0) {
                status = "OVER";
            }
        } else if (rate < 4) {
            void *end_state = ch->copy_state();
            ch->restore_state(start_state);

            clientStub->SetRate(rate + 2);
            clientStub->SetPacketSize(6);
    
            UINT64 errors = clientStub->GetErrors();
            UINT64 total = clientStub->GetTotalBits();
            double hint = GetHint();

            if (errors == 0) {
                status = "UNDER";
            }

            ch->restore_state(end_state);
            ch->free_state(end_state);
        }

        printf("[%9d] rate: %d %s errors: %lu total: %lu hint: 2^%2.3lf\n",
                ch->Cycle(), rate, status, errors, total, hint);

#if VITERBI == 1
        rate = choose_rate_viterbi(rate, hint);
#else
        rate = choose_rate(rate, hint);
#endif

        ch->free_state(start_state);
    }

    clientStub->Finish(0);
}

// register driver
static RegisterDriver<AIRBLUE_RATE_DRIVER_CLASS> X;
