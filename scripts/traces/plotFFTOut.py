#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt

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
for line in datain.readlines():
  components = line.split(':')
  if(len(components) == 4 and components[0] == 'ChannelEstIn'):
    print "writing: " + str(int(components[2])) + " + " + str(int(components[3])) + "j"  
    reals[linecount] = int(components[2])
    imags[linecount] = int(components[3])
    if(linecount == 63):
      plt.figure()
      plt.plot(reals,imags, linestyle='None', marker='*')
      linecount = 0
    else:
      linecount = linecount + 1


plt.show()



