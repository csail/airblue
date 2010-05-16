#ifndef CHANNEL_H
#define CHANNEL_H

//Noise variance
#define DEFAULT_SNR 30 // signal to noise ratio
#define PI (4*atan2(1,1))
#define TIME_STEP 5e-8
//#define DELTA_F 100000

#define SIGNAL_POWER 0.0125

#ifdef __cplusplus 
extern "C" {
#endif

int awgn(unsigned int data);
int cfo(unsigned int data, int cycle);
int rayleigh_channel(unsigned int data, int cycle);
unsigned char isset(const char *str);

typedef struct {
  double rel;
  double img;
} Complex;

double rand_double();

double gaussian();

double getenvd(const char*, double d);


double get_snr();

/* Computes the standard deviation from SNR */
double compute_sigma(double snr);

Complex gaussian_complex(double sigma);

Complex add_complex_noise(Complex signal, double sigma);

Complex mult_complex(Complex a, Complex b);

Complex rotate_complex(Complex signal, double rot);

Complex cmplx(short int real, short int imag);

unsigned int pack(Complex x);
Complex unpack(unsigned int x);

double abs2(Complex x);

#ifdef __cplusplus 
}
#endif

#endif
