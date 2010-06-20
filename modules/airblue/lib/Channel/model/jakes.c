#include "util.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

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


  coeff_real *= sqrt(2.0/JAKES_M);
  coeff_imag *= sqrt(2.0/JAKES_M);

  double norm = sqrt(coeff_real*coeff_real + coeff_imag*coeff_imag);
  norm *= 1;

#if VERBOSE
  printf("jakes time=%f coeff=%.3f%+.3f norm=%.3f\n", 
	 d_time, coeff_real, coeff_imag, norm);
#endif
  
  Complex ret = { rel: coeff_real, img: coeff_imag };
  return ret;
}

Complex rayleigh_channel(Complex signal, int cycle, int rotate)
{
  double d_time = cycle * sample_time;

  // Rayleigh fading
  Complex coeff = get_sample_coeff(d_time);
  if (rotate) {
    return mult_complex(signal, coeff);
  } else {
    double m = sqrt(coeff.rel * coeff.rel + coeff.img * coeff.img);
    signal.rel *= m;
    signal.img *= m;
    return signal;
  }
}

int rayleigh_channel_bdpi(unsigned int data, int cycle)
{
  return pack(rayleigh_channel(unpack(data), cycle, 1));
}

#ifdef JAKES_TEST
int main(int argc, char** argv)
{
  model_init();
  double d_time = 0.0;
  double sum_square = 0.0;
  int count = 0;
  while (d_time < 1000) {
    Complex coeff = get_sample_coeff(d_time);
    sum_square += ( coeff.rel * coeff.rel + coeff.img * coeff.img );
    count += 1;
    d_time += 10000 * sample_time; //0.001;
  }
  sum_square /= count;
  printf("power: %lf (count=%d)\n", 10.0 * log(sum_square) / log(10.0), count);
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
