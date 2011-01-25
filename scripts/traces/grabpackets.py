#!/usr/bin/env python

from optparse import OptionParser
import os
import numpy
import sys
import struct

def intsfromfile(f, outfile_prefix,chunk,decimation,threshold):
  chunk_cnt = 0;
  while True:
#    complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
    a = numpy.fromstring(f.read(chunk*4), dtype=numpy.int16)
    measurements = a.size /(decimation*2)
    print a.size
    exceed_threshold  = 0
    if a.size == 0:
      break
    for i in range(0,measurements-1):
      idx = i*decimation
      if abs(a[idx]) > threshold or abs(a[idx+1]) > threshold:
        exceed_threshold = 1
        break
    if exceed_threshold:
      fileno = chunk_cnt*chunk
      print "{0}_{1}".format(outfile_prefix,fileno)
      a.tofile("{0}_{1}".format(outfile_prefix,fileno))
    print exceed_threshold
    chunk_cnt += 1;

parser = OptionParser()
# parser.add_option("-s", "--start", dest="start", type=int, default=0, help="start sample of subwindow to dump")
# parser.add_option("-f", "--finish", dest="finish", type=int, default=0, help="end sample of subwindow to dump rate (default 1)")
parser.add_option("-d", "--decimation", dest="decimation", type=int, default=1, help="decimation rate (default 1)")

(options, args) = parser.parse_args()

if len(args) < 4:
  print "Usage: grabpackets.py input.file output.file chunk.size threshold\n"
  sys.exit(-1)

# measurements = os.path.getsize(args[0])/4

# start = 0
# if(options.start > 0):
#   start = options.start

# finish = measurements
# if(options.finish > 0):
#   finish = options.finish

fr = open(args[0], "r")

# print "range: " + str(start) + ":" + str(finish)

intsfromfile(fr, args[1], int(args[2]), options.decimation, int(args[3]))

fr.close()
# fw.close()


