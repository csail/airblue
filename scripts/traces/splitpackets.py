#!/usr/bin/env python

from optparse import OptionParser
import os
import numpy
import sys
import struct

def intsfromfile(f, out_file_name, chunk):
  chunk_no = 0
  remain = chunk
  wr_new_file = 0
  i = 0
  fw = open("{0}_{1}".format(out_file_name,chunk_no), "w")
  while True:
    if remain <= 1000000:
      rd_size = remain * 4
      remain = chunk
      chunk_no += 1
      wr_new_file = 1
    else:
      rd_size = 4000000
      remain -= 1000000
      i += 1
    a = f.read(rd_size)
    if len(a) == 0:
      fw.close()
      break
    fw.write(a)
    if i%25 == 0:
      print "{0}".format(i/25)
    if wr_new_file:
      wr_new_file = 0
      fw.close()
      fw = open("{0}_{1}".format(out_file_name,chunk_no), "w")

parser = OptionParser()
# parser.add_option("-s", "--start", dest="start", type=int, default=0, help="start sample of subwindow to dump")
# parser.add_option("-f", "--finish", dest="finish", type=int, default=0, help="end sample of subwindow to dump rate (default 1)")
#parser.add_option("-d", "--decimation", dest="decimation", type=int, default=1, help="decimation rate (default 1)")

(options, args) = parser.parse_args()

if len(args) < 3:
  print "Usage: splitpackets.py input.file output.file chunk.size\n"
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
intsfromfile(fr, args[1], int(args[2]))

fr.close()


