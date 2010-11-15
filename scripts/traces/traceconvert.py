#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt

parser = OptionParser()
parser.add_option("-d", "--decimation", dest="decimation", type=int, default=1, help="decimation rate (default 1)")
parser.add_option("-s", "--skip", dest="skip", type=float, default=0.0, help="initial seconds to skip (default 0.1)")
(options, args) = parser.parse_args()

if len(args) < 2:
  sys.exit(-1)

datain = open(args[0], "r");

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
linecount = 0
for line in datain.readlines():
  linecount = linecount + 1

magnitudes = numpy.empty((linecount,), dtype=complexint)
linecount = 0
datain = open(args[0], "r");
for line in datain.readlines():
  components = line.split(':')
  linecount = linecount + 1
  if(len(components) == 3):
    print "writing: " + str(int(components[1])) + " + " + str(int(components[2])) + "j"  
    magnitudes[linecount]["real"] = int(components[1])
    magnitudes[linecount]["imag"] = int(components[2])
  

magnitudes.tofile(args[1]);



