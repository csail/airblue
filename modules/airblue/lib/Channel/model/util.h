#ifndef _CHANNEL_UTIL_
#define _CHANNEL_UTIL_

//Noise variance
#define DEFAULT_SNR 30 // signal to noise ratio
#define PI (4*atan2(1,1))
#define TIME_STEP 5e-8
//#define DELTA_F 100000

#define SIGNAL_POWER 0.0125

#ifdef __cplusplus 
extern "C" {
#endif

typedef struct {
  double rel;
  double img;
} Complex;

void model_init();
void jakes_init();

void* copy_state();
void restore_state(void *state);
void free_state(void *state);

Complex awgn(Complex data, double snr);
Complex cfo(Complex data, double freq_offset, int cycle);
Complex rayleigh_channel(Complex data, int cycle, int rotate);

int awgn_bdpi(unsigned int data);
int cfo_bdpi(unsigned int data, int cycle);
int rayleigh_channel_bdpi(unsigned int data, int cycle);


double rand_double();
Complex gaussian();
Complex gaussian_fast();

double getenvd(const char*, double d);
int getenvi(const char*, int d);
unsigned char isset(const char *str);

double get_snr();

/* Computes the standard deviation from SNR */
double compute_sigma(double snr);

Complex gaussian_complex(double sigma);

Complex add_complex_noise(Complex signal, double sigma);

Complex add_complex(Complex a, Complex b);
Complex mult_complex(Complex a, Complex b);

Complex rotate_complex(Complex signal, double rot);

Complex cmplx(double real, double imag);

unsigned int pack(Complex x);
Complex unpack(unsigned int x);

double abs2(Complex x);

#ifdef __cplusplus 
}
#endif

#endif
