#!/usr/bin/python

import commands
import re
import math
import numpy

def two2ten(ber):
    if ber == float('-inf'):
        return ber

    return math.log(2 ** ber, 10)

def main():
    files = commands.getoutput('find | grep hardware.out').split("\n")
    out = open('packet-ber.dat', 'w')
 
    bers = []

    p = re.compile('Packet predicted: 2\^(.*?) actual: 2\^(.*?) ')

    for filename in files:
        contents = open(filename, 'r').readlines()
        for line in contents:
            m = p.match(line)
            if m != None:
                pred, actual = map(float, m.groups())

                # bin prediction
                pred = max(-4, round(two2ten(pred), 1))

                # compute actual BER as a deicmal
                actual = 2.0 ** actual

                bers.append( (pred, actual ) )

    for ber in [-x / 10.0 for x in range(0, 41)]:
        actual = [actual for (pred, actual) in bers if pred == ber]

        if len(actual) == 0:
            continue

        out.write('%.20f %.20f %.20f\n' % (10.0 ** ber, numpy.mean(actual),
            numpy.std(actual)))

if __name__ == '__main__':
    main()
