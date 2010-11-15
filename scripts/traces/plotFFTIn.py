#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt
import cmath

parser = OptionParser()
(options, args) = parser.parse_args()

if len(args) < 1:
  sys.exit(-1)

datain = open(args[0], "r");

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
linecount = 0
for line in datain.readlines():
  linecount = linecount + 1

reals = numpy.empty((64,), dtype=numpy.int16)
imags = numpy.empty((64,), dtype=numpy.int16)
linecount = 0
datain = open(args[0], "r");
timedomain = []
for line in datain.readlines():
  components = line.split(':')
  if(len(components) == 4 and components[0] == 'FFTIn'):
    print "writing: " + str(int(components[2])) + " + " + str(int(components[3])) + "j"  
    timedomain.append(complex(int(components[2]), int(components[3])))
    print 'td:'+ str(len(timedomain)) +' :' + str(timedomain)
    reals[linecount] = int(components[2])
    imags[linecount] = int(components[3])
    if(linecount == 63):
      plt.figure()
      plt.subplot(221)
      plt.title('timedomain')
      plt.plot(reals,imags, linestyle='None', marker='*')
      print 'td:'+ str(len(timedomain)) +' :' + str(timedomain)
      fft = numpy.fft.fftshift(numpy.fft.fft(timedomain))
      realT = []
      imagT = []
      for i in range(0,64):
        realT.append(fft[i].real)
        imagT.append(fft[i].imag)
      plt.subplot(222)
      plt.title('frequency domain')
      plt.plot(realT,imagT, linestyle='None', marker='*')
      plt.subplot(223)
      plt.title('fft mag')
      print 'Mags: ' + str(map(abs,fft))
      plt.plot(abs(fft)) 
      plt.subplot(224)
      plt.title('fft phase')
      print 'Phases: ' + str(map(cmath.phase,fft))
      plt.plot(map(cmath.phase,fft)) 
      linecount = 0
      timedomain = []
    else:
      linecount = linecount + 1


plt.show()



