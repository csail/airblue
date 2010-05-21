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
my $pktsz_bytes = 256;
my $pktsz_bits = $pktsz_bytes*8; 

if ($#ARGV < 0) {
  print "analyze-softphy.pl: missing file\n";
  print "Usage: perl analyze-softphy.pl <file>\n";
  exit(1);
}

my $softphy_file = $ARGV[0]; #"softphy.txt";
my $biterror_file = $ARGV[0]; #"ber.txt";

my @actual_bers = ();
my @total_softphy = ();

sub mean {
    my ($array_ref) = @_;
    my $sum = 0;
    foreach (@$array_ref) {
        $sum += $_;
    }
    return $sum / (scalar @$array_ref);
}

sub process_softphy {

    my $unique_cnt = 0;

    open SOFTPHY, "$softphy_file" || die "cant open softphy";

    for(my $i=0; $i < 256; $i = $i + 1) {
	$actual_bers[$i] = 0;
        $total_softphy[$i] = 0;
    }

    while(my $line = <SOFTPHY>) {
       
        if($line =~ m/h:\s+(\d+)\s+e:\s+(\d+)/) {
            $total_softphy[$1] = $total_softphy[$1] + 1;
            if($2) {
                $actual_bers[$1] = $actual_bers[$1] + 1;
	    }
        }
    }

}

sub print_results {

    open OUT, ">meansoft-vs-ber.raw" || die "cant open dat file";
    for(my $i=0; $i<256; $i++) {
        print OUT $actual_bers[$i]." ".$total_softphy[$i]."\n";
    }

    open OUT, ">meansoft-vs-ber.dat" || die "cant open dat file";
    for(my $i=0; $i<256; $i++) {
        if($total_softphy[$i] > 0) {
           print OUT $i ." ".$actual_bers[$i]/$total_softphy[$i]."\n";
	} else {
           print OUT $i ." 0\n";
	}

    }

    #system "gnuplot plot-ber.gp > meansoft-vs-ber.eps";
        
}


process_softphy();
print_results();
