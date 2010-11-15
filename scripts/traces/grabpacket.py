#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt

parser = OptionParser()
parser.add_option("-s", "--start", dest="start", type=int, default=0, help="start sample of subwindow to dump")
parser.add_option("-f", "--finish", dest="finish", type=int, default=0, help="end sample of subwindow to dump rate (default 1)")

(options, args) = parser.parse_args()

if len(args) < 2:
  sys.exit(-1)

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
readdata = numpy.fromfile(file=open(args[0], "rb"), dtype=complexint)

measurements = readdata.shape[0]


start = 0
if(options.start > 0):
  start = options.start

finish = readdata.shape[0]
if(options.finish > 0):
  finish = options.finish

print "range: " + str(start) + ":" + str(finish)

magnitudes = numpy.empty((finish-start,), dtype=complexint)

j=0
for i in range(start, finish):
  magnitudes[j] = readdata[i]
  j=j+1

magnitudes.tofile(args[1])


