#include "util.h"

#include <math.h>
#include <stdio.h>

/* -*- c++ -*- */
/*
 * Copyright 2004,2006 Free Software Foundation, Inc.
 * 
 * This file is part of GNU Radio
 * 
 * GNU Radio is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 * 
 * GNU Radio is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with GNU Radio; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#define VERBOSE 0

#define JAKES_M 8
#define JAKES_DOPPLER_DEFAULT 10

#ifndef M_PI
#define M_PI 3.14159
#endif

static const double sample_time = 5.0e-8;

static double theta;
static double phi;
static double psi[JAKES_M];
static double alpha[JAKES_M];
static double d_time = 0;
static double d_doppler;

static double random_phase()
{
  double d = rand_double();
  double phase = 2 * M_PI * d - M_PI;
  return phase;
}

static void jakes_init()
{
  theta = random_phase();
  phi = random_phase();
  d_doppler = 2 * M_PI * getenvd("JAKES_DOPPLER", JAKES_DOPPLER_DEFAULT);
 
  int n;
  for(n=0; n < JAKES_M; n++) {
    psi[n] = random_phase();
    alpha[n] = (2*M_PI*n - M_PI+theta)/(4*JAKES_M);
  }

#if VERBOSE
  printf("Jakes Simulator: sample_time %.10f s, doppler_spread %.6f radians, M %d\n",
	 sample_time, d_doppler, JAKES_M);
#endif
}

Complex get_sample_coeff(double d_time)
{
  static int init = 0;
  if (!init) {
    jakes_init();
    init = 1;
  }

  double coeff_real = 0.0;
  double coeff_imag = 0.0;

  int n;
  for(n=0; n < JAKES_M; n++) {
    coeff_real += cos(psi[n])*cos(d_doppler*d_time*cos(alpha[n]) + phi);
    coeff_imag += sin(psi[n])*cos(d_doppler*d_time*cos(alpha[n]) + phi);
  }

  coeff_real *= 2/sqrt(JAKES_M);
  coeff_imag *= 2/sqrt(JAKES_M);

  double norm = sqrt(coeff_real*coeff_real + coeff_imag*coeff_imag);
  norm *= 1;

#if VERBOSE
  printf("jakes time=%f coeff=%.3f%+.3f norm=%.3f\n", 
	 d_time, coeff_real, coeff_imag, norm);
#endif
  
  Complex ret = { rel: coeff_real, img: coeff_imag };
  return ret;
}

int rayleigh_channel(unsigned int data, int cycle)
{
  double d_time = cycle * sample_time;

  Complex signal = unpack(data);

  // Rayleigh fading
  Complex coeff = get_sample_coeff(d_time);
  Complex faded = mult_complex(signal, coeff);

  return pack(faded);
}

#ifdef JAKES_TEST
int main(int argc, char** argv)
{
  double d_time = 0.0;
  double sum_square = 0.0;
  double count = 0.0;
  while (d_time < 1.0) {
    Complex coeff = get_sample_coeff(d_time);
    double mag = sqrt(coeff.rel * coeff.rel + coeff.img * coeff.img);
    sum_square += mag*mag;
    count += 1;
    printf("%lf, %lf\n", d_time, mag);
    d_time += 0.001;
  }
  //printf("rms: %lf\n", sqrt(sum_square/count));
}
#endif

//gr_jakes_simulator::work (int noutput_items,
//			     gr_vector_const_void_star &input_items,
//			     gr_vector_void_star &output_items)
//{
//  gr_complex *in = (gr_complex *) input_items[0];
//  gr_complex *out = (gr_complex *) output_items[0];
//  gr_complex *out_coeff = (gr_complex *) output_items[1];
//
//  for(int i=0; i < noutput_items; i++) {
//    gr_complex coeff = get_sample_coeff();
//
//#if VERBOSE
//    printf("coeff mag=%.3f phase=%.3f\n", 
//	   sqrt(norm(coeff)), arg(coeff));
//#endif
//
//    out[i] = gr_complex(sqrt(norm(coeff)),0)*in[i];
//    //out[i] = coeff*in[i];
//    out_coeff[i] = coeff;
//  }
//  
//  return noutput_items;
//}
