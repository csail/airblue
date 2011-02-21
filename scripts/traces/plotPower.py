#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt

parser = OptionParser()
parser.add_option("-d", "--decimation", dest="decimation", type=int, default=1, help="decimation rate (default 1)")
parser.add_option("-m", "--maximum", dest="max", type=int, default=-1, help="maximum timestamp")
parser.add_option("-s", "--skip", dest="skip", type=float, default=0.0, help="initial seconds to skip (default 0.0)")
(options, args) = parser.parse_args()

if len(args) < 2:
  sys.exit(-1)

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])
readdata = numpy.fromfile(file=open(args[0], "rb"), dtype=complexint)
measurements = readdata.shape[0] / options.decimation
skip = (options.skip * 20000000) / options.decimation
magnitudes = numpy.empty((measurements,), dtype=numpy.uint16)
timemag = []
#Need this part for the magnitudes
for i in numpy.arange(measurements):
#  print 'img '  + str(readdata[i * options.decimation]["imag"]) + ' rel: ' + str( readdata[i * options.decimation]["real"])
  magnitudes[i] = numpy.sqrt(readdata[i * options.decimation]["real"]**2 + readdata[i * options.decimation]["imag"]**2)
  timemag.append(i*40)
del(readdata)

datain = open(args[1], "r");


reals = []

timestamp = []

time = 200

for line in datain.readlines():
  components = line.split(':')
  if(len(components) == 2 and components[0] == 'Total Power'):
    print "writing: " + str(float(components[1]))  
    reals.append(float(components[1]))
    timestamp.append(time)
    time = time + 200

fig = plt.figure()
ax1 = fig.add_subplot(111)
ax1.plot(timemag, magnitudes,'b-')

ax2 = ax1.twinx()
ax2.plot( timestamp, reals, 'r.')

plt.show()
