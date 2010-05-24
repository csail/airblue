#include <iostream>
#include <fstream>
#include "util.h"

#define SIZE 1320

static Complex data[SIZE];
static int counter = 0;

void init_synchronizer_data()
{
  std::ifstream in;
  in.open("packet.data");

  if (!in) {
    std::cerr << "Error: packet.data could not be opened" << std::endl;
  }

  for (int i = 0; i < SIZE; i++) {
    double real, imag;
    in >> real >> imag;
    data[i] = cmplx(real, imag);
  }

  in.close();
}

bool get_next_sample(Complex *sample)
{
  bool start = (counter == 500);

  *sample = data[counter];

  counter++;
  counter %= SIZE;

  return start;
}
