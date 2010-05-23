#!/usr/bin/perl

# determine awb directory

$working_dir = `awb-resolver scripts/aggregation/soft_phy/`;
chomp($working_dir);

print "working dir is $working_dir\n";

`regression.launcher --package=ofdm --runtype=soft_phy_half --runcmds="\\"-completioncmd=$working_dir/aggregate-ber-bins.pl $working_dir/plot-ber.gp\\""`;

