#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt

parser = OptionParser()
parser.add_option("-d", "--decimation", dest="decimation", type=int, default=1, help="decimation rate (default 1)")
parser.add_option("-s", "--skip", dest="skip", type=float, default=0.0, help="initial seconds to skip (default 0.1)")
(options, args) = parser.parse_args()

if len(args) < 1:
  sys.exit(-1)

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
readdata = numpy.fromfile(file=open(args[0], "rb"), dtype=complexint)
measurements = readdata.shape[0] / options.decimation
skip = (options.skip * 20000000) / options.decimation
magnitudes = numpy.empty((measurements,64), dtype=complex)
for i in numpy.arange(measurements):
  if(i < measurements - 64):
    timedomain = []
    for j in range(0,64):
      timedomain.append(complex(readdata[i+j]["real"], readdata[i+j]["imag"]))
    magnitudes[i] = numpy.fft.fftshift(numpy.fft.fft(timedomain))
    #print "timedomain: " + str(timedomain)

magnitudes = abs(magnitudes)

del(readdata)
plt.imshow(numpy.transpose(magnitudes),aspect='auto')
plt.colorbar()
plt.show()
