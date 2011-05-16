#!/usr/bin/env python
from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt
import math

parser = OptionParser()
parser.add_option("-s", "--symbols", dest="symbols", type=int, default=50, help="number of symbols to print (default 50)")
(options, args) = parser.parse_args()

numberPlotted = 0

if len(args) < 1:
  sys.exit(-1)

datain = open(args[0], "r");

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
linecount = 0
ratelast = 9

values = [[]]
scale = [[]]

datain = open(args[0], "r");
for line in datain.readlines():
  components = line.split(':')
  if(len(components) == 8 and components[0] == 'Rate'):
    if(ratelast != int(components[1])):
      values.append([])
      scale.append([])
    ratelast = int(components[1])
    values[ratelast].append(float(components[5]))
    scale[ratelast].append(float(components[3])/(1<<16))

ratelast = ratelast + 1

for index in range(0,ratelast):
#      plt.figure()
      plt.plot(scale[index],values[index])


plt.show()





