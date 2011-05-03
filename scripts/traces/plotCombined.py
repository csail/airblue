#!/usr/bin/env python
from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt
import math

parser = OptionParser()
parser.add_option("-s", "--symbols", dest="symbols", type=int, default=20, help="number of symbols to print (default 20)")
parser.add_option("-m", "--match", dest="match", type=int, default=0, help="point at which to start printing correct values (default 0)")
(options, args) = parser.parse_args()

numberPlotted = 0

if len(args) < 1:
  sys.exit(-1)

datain = open(args[0], "r");
correctin = open(args[1], "r");

complexint = numpy.dtype([("real", numpy.int16), ("imag", numpy.int16)])

reals_good = numpy.empty((64,), dtype=numpy.int16)
imags_good = numpy.empty((64,), dtype=numpy.int16)
mags_good = []
phases_good = []
correct_lines = correctin.readlines()
correct_index = 0


linecount = 0
for line in datain.readlines():
  linecount = linecount + 1

reals = numpy.empty((64,), dtype=numpy.int16)
imags = numpy.empty((64,), dtype=numpy.int16)
linecount = 0
datain = open(args[0], "r");
correctin = open(args[1], "r");

for line in datain.readlines():
  components = line.split(':')
  if(len(components) == 4 and components[0] == 'ChannelEstIn'):
    print "writing: " + str(int(components[2])) + " + " + str(int(components[3])) + "j"  
    reals[linecount] = int(components[2])
    imags[linecount] = int(components[3])
    if(linecount == 63):
      if(numberPlotted >= options.match):


        for linecount in range(0,64):
          components = correct_lines[correct_index+linecount].split(':')
          if(len(components) == 4 and components[0] == 'IFTIn'):
            reals_good[linecount] = int(components[2])
            imags_good[linecount] = int(components[3])
      
        mags_good = []
        for i in range(0,64):
          mags_good.append(math.sqrt(math.pow(reals_good[i],2)+math.pow(imags_good[i],2)))

        phases_good = []
        for i in range(0,64):
          phases_good.append( math.atan2(imags_good[i],reals_good[i]))

        correct_index = correct_index + 64


        plt.figure()
        plt.subplot(221)
        plt.plot(reals,imags, linestyle='None', marker='*')
        plt.subplot(222)
        plt.plot(reals_good,imags_good, linestyle='None', marker='*')
        plt.subplot(223)
        plt.title('fft mag')
        mags = []
        for i in range(0,64):
          mags.append(math.sqrt(math.pow(reals[i],2)+math.pow(imags[i],2)))
       
        plt.plot(mags,"r")
        plt.plot(mags_good,"b")
        plt.subplot(224)
        plt.title('fft phase')
        phases = []
        # abs here makes bpsk easier to look at
        for i in range(0,64):
          phases.append( math.atan2(imags[i],reals[i]))
        print 'Phases: ' + str(phases)
        plt.plot(phases,"r")
        plt.plot(phases_good,"b")

      linecount = 0
      plt.savefig('combined' + str(numberPlotted) + '.png')
      numberPlotted = numberPlotted + 1
      # we want to display correct values here
      if(numberPlotted  > options.symbols):
        break
    else:
      linecount = linecount + 1

plt.show()





