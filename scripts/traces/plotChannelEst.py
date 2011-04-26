#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt
import math

parser = OptionParser()
parser.add_option("-s", "--symbols", dest="symbols", type=int, default=50, help="number of symbols to print (default 50)")
(options, args) = parser.parse_args()

if len(args) < 1:
  sys.exit(-1)

numberPlotted = 0

datain = open(args[0], "r");

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
linecount = 0
for line in datain.readlines():
  linecount = linecount + 1

reals = numpy.empty((64,), dtype=numpy.int16)
imags = numpy.empty((64,), dtype=numpy.int16)
for i in range(0,64):
  reals[i] = 0
  imags[i] = 0

linecount = 0
datain = open(args[0], "r");
for line in datain.readlines():
  components = line.split(':')
  if(len(components) == 5 and components[0] == 'ChannelEstOut'):
    print "writing: " + str(linecount) + " + " + str(int(components[3])) + "j"  
    reals[int(components[1])] = int(components[3])
    imags[int(components[1])] = int(components[4])
    if(linecount == 47):
      plt.figure()
      plt.subplot(221)
      maxvalue = max(reals + imags)
      plt.plot(reals,imags, linestyle='None', marker='*')
      plt.ylim(-maxvalue,maxvalue)
      plt.xlim(-maxvalue,maxvalue)
      print "maxvalue: " + str(maxvalue)
      plt.subplot(223)
      plt.title('fft mag')
      mags = []
      for i in range(0,64):
         mags.append(math.sqrt(math.pow(reals[i],2)+math.pow(imags[i],2)))
      plt.plot(mags)
      plt.subplot(224)
      plt.title('fft phase')
      phases = []
      for i in range(0,64):
        phases.append( math.atan2(imags[i],reals[i]))
      print 'Phases: ' + str(phases)
      plt.plot(phases,linestyle='None', marker='*')

      linecount = 0
      numberPlotted = numberPlotted + 1
      if(numberPlotted  > options.symbols):
        break
    else:
      linecount = linecount + 1


plt.show()



