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
magnitudes = numpy.empty((measurements,), dtype=numpy.uint16)
avgpow = 0

for i in range(0,measurements-16):
  magnitudes[i] = numpy.sqrt(readdata[i * options.decimation]["real"]**2 + readdata[i * options.decimation]["imag"]**2)

packets = 0
i = 0
while(i < measurements-216):
  avgpow = 0
  for j in range(0,16):
    avgpow += magnitudes[i+j]/16

  if(avgpow > 300):
    print "found a packet at " + str(i)
    len = 0
    for j in range(i,measurements-200-16):
      avgpow = 0
      for k in range(j,j+16):
        avgpow += magnitudes[k]/16 

      if(avgpow < 100):
        break
      len = len + 1
    print "length is " + str(len)
    #dump packet
    offset = i
    if(i > 200):
      offset = 200

    # grab packet
    packet = numpy.empty((offset+len+200,),complexint)
    packetIndex = 0
    for j in range(i-offset,i+len+200):
      packet[packetIndex] = readdata[j]
      packetIndex = packetIndex + 1

    packet.tofile(args[1] + '_' + str(packets))

    # grab preamble
    preamble = numpy.empty((offset+400,),complexint)
    preambleIndex = 0
    for j in range(i-offset,i+400):
      preamble[preambleIndex] = readdata[j]
      preambleIndex = preambleIndex + 1

    preamble.tofile(args[1] + '_preamble_' + str(packets))

    packets = packets + 1
    i = i + len + 200
  else:
    i = i + 1

