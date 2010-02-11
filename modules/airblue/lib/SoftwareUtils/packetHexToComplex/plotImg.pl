#!/usr/bin/perl
`cat $ARGV[0] | ./packetHexToComplex > plot.txt`;
`gnuplot packetImgPlot.txt`;
`mv my-plot.ps $ARGV[0].ps`;
