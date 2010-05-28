#!/usr/bin/perl -w

# USAGE
#
# ./phy_test | grep "bit errors\|softphy" > logfile
# perl analyze-softphy.pl logfile
# gnuplot plot-ber.gp meansoft-vs-ber.dat > meansoft-vs-ber.eps
#

use strict;
#use util;

my $numpkts=0;

if ($#ARGV < 0) {
  print "analyze-softphy.pl: missing file\n";
  print "Usage: perl analyze-softphy.pl <file>\n";
  exit(1);
}
