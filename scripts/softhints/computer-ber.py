#!/usr/bin/python

import sys
import numpy
import math
from optparse import OptionParser


def output_file(f, rate, filetype, log_domain, fit):
    print "// generated by compute-ber.py"
    print "// table for rate %d (%s)" % (rate, "curve fit" if fit else "exact")
    print "// (computed without odd hints)"
    print

    if filetype == 'bsv':
        print "function BitErrorRate getBER_R%d(SoftPhyHints hint);" % rate
        print "   case (hint) matches"
    else:
        print "double get_ber_r%d(UINT8 hint) {" % rate
        print "   switch (hint) {"
    
    for h in range(0,64):
        ber = f(h)
        #if (ber < 2.0 ** -32): break

        if log_domain:
            ber = -63.0 if ber == 0 else math.log(ber, 2)
            ber = min(ber, -1)
        else:
            ber = max(ber, 0)
            ber = min(ber, 0.5)

        print "      %2d: return %.15f;" % (h, ber)
    print "      default: return %d;" % (-63 if log_domain else 0)
    
    if filetype == 'bsv':
        print "   endcase"
        print "endfunction"
    else:
        print "   }"
        print "}"

def main():
    usage = "usage: %prog [options] file rate"
    parser = OptionParser(usage=usage)
    parser.add_option("-c", "--cpp", dest="filetype", default="bsv",
                      action="store_const", const="cpp", help="output C++")
    parser.add_option("-b", "--bsv", dest="filetype", default="bsv",
                      action="store_const", const="bsv", help="output BSV")
    parser.add_option("-l", "--log", dest="log", default=False,
                      action="store_true", help="output log domain")
    parser.add_option("-f", "--fit", dest="fit", default=False,
                      action="store_true", help="fit curve")
    parser.add_option("-p", "--plot", dest="plot", default=False,
                      action="store_true", help="plot curve")

    (options, args) = parser.parse_args()

    if len(args) < 1:
        parser.error("missing filename")
    if len(args) < 2:
        parser.error("missing rate")

    filename, rate = args
    rate = int(rate)
    f = open(filename, 'r')

    strs = [line.split() for line in f.read().split('\n')[:-1]]
    errors = [int(line[0]) for line in strs]
    totals = [int(line[1]) for line in strs]

    errors = numpy.array(errors, dtype='double')
    totals = numpy.array(totals, dtype='double')

    ber = numpy.log(((errors / totals) ** -1) - 1)

    idxs = numpy.nonzero(~numpy.isnan(ber) & numpy.isfinite(ber))[0]

    # ignore odd hints for now
    idxs = idxs[numpy.nonzero(idxs % 2 == 0)]

    ber = ber[idxs]

    (a,b) = numpy.polyfit(idxs, ber, 1)

    if options.fit:
        func = lambda hint: (numpy.exp(a * hint + b) + 1) ** -1
    else:
        func = lambda hint: errors[hint] / totals[hint]

    output_file(func, rate, options.filetype, options.log, options.fit)

    if options.plot:
        predicted = numpy.array([func(i) for i in range(len(totals))])
        ber = errors / totals

        from matplotlib import pyplot as p
        p.semilogy(ber)
        p.semilogy(predicted)
        p.show()

if __name__ == '__main__':
    main()
