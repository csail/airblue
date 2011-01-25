#!/usr/bin/env python

from optparse import OptionParser
import os
import array
import sys
import struct

assert array.array('i').itemsize == 4

def intsfromfile(f, start_pos, finish_pos):
  pos = 0;
  while True:
     a = array.array('i')
     a.fromstring(f.read(4000))
     if pos > finish_pos:
       break
     if not a:
       break
     if pos+1000 < start_pos:
       pos += 1000
       continue
     for x in a:
       if start_pos <= pos and pos <= finish_pos:
         yield x
       pos += 1


parser = OptionParser()
parser.add_option("-s", "--start", dest="start", type=int, default=0, help="start sample of subwindow to dump")
parser.add_option("-f", "--finish", dest="finish", type=int, default=0, help="end sample of subwindow to dump rate (default 1)")

(options, args) = parser.parse_args()

if len(args) < 2:
  print "Usage: grabpacket.py [-s start_pos] [-f finish_pos] input.file output.file\n"
  sys.exit(-1)

measurements = os.path.getsize(args[0])/4

start = 0
if(options.start > 0):
  start = options.start

finish = measurements
if(options.finish > 0):
  finish = options.finish

fr = open(args[0], "r")
fw = open(args[1], "wb")

print "range: " + str(start) + ":" + str(finish)

for i in intsfromfile(fr, start, finish):
  data = struct.pack('i',i)
  fw.write(data)

fr.close()
fw.close()


