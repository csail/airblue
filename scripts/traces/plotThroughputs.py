#!/usr/bin/env python

from optparse import OptionParser
import numpy
import matplotlib.pyplot as plt

parser = OptionParser()
(options, args) = parser.parse_args()

if len(args) < 1:
  sys.exit(-1)

datain = open(args[0], "r");

linecount = 0
for line in datain.readlines():
  linecount = linecount + 1

fifosIn = {}
fifosOut = {}
fifosCount = {}
linecount = 0
datain = open(args[0], "r");
for line in datain.readlines():
  components = line.split(':')
  if(len(components) == 10 and (components[0] == 'ThroughputIn')):
#    print 'looking at ' + components[1] + '\n'
    if(fifosIn.has_key(components[1])):
      fifosIn[components[1]]['time'].append(int(components[5]))
      fifosIn[components[1]]['activity'].append(int(components[7]))
    else:
      fifosIn[components[1]] = {'time':[],'activity':[]}

    if(int(components[5]) > 5000):
      break

  if(len(components) == 10 and ( components[0] == 'ThroughputOut')):
#    print 'looking at ' + components[1] + '\n'                                                                            
    if(fifosOut.has_key(components[1])):
      fifosOut[components[1]]['time'].append(int(components[5]))
      fifosOut[components[1]]['activity'].append(int(components[7]))
    else:
      fifosOut[components[1]] = {'time':[],'activity':[]}

  if(len(components) == 10 and (components[0] == 'ThroughputIn' or  components[0] == 'ThroughputOut')):
#    print 'looking at ' + components[1] + '\n'
    if(fifosCount.has_key(components[1])):
      fifosCount[components[1]]['time'].append(int(components[5]))
      fifosCount[components[1]]['activity'].append(int(components[11]))
    else:
      fifosCount[components[1]] = {'time':[],'activity':[]}


for fifo in fifosIn.keys():
  fig = plt.figure()
  #ax1 = fig.add_subplot(111
  print 'looking at ' + fifo + '\n'
  plt.plot(fifosIn[fifo]['time'],fifosIn[fifo]['activity'],label=fifo + ' In')
  plt.plot(fifosOut[fifo]['time'],fifosOut[fifo]['activity'],label=fifo+' Out')
  plt.plot(fifosCount[fifo]['time'],fifosCount[fifo]['activity'],label=fifo+' Count')
  plt.legend()
  

plt.show()






