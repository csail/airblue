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

my $softphy_file = $ARGV[0]; #"softphy.txt";
my $biterror_file = $ARGV[0]; #"ber.txt";

my @actual_bers = ();
my @projected_bers = ();


sub process_softphy {

    my $unique_cnt = 0;

    open SOFTPHY, "$softphy_file" || die "cant open softphy";

    my $packet_errors = 0;
    my $packet_bits = 0;
    while(my $line = <SOFTPHY>) {
        # encountered end of packet, emit projected ber/actual ber pair
        # need some way of collecting the projected ber...
        if($line =~ m/EOP/) {
           my $actual_ber =  $packet_errors/$packet_bits;
           print "Got EOP $actual_ber\n";
           $actual_bers[$numpkts] = $actual_ber;
           $projected_bers[$numpkts] = 0;;
           $packet_errors = 0;
           $packet_bits = 0;
           $numpkts = $numpkts + 1;
        }       
       
        if($line =~ m/h:\s+(\d+)\s+e:\s+(\d+)/) {
            $packet_bits = $packet_bits + 1; 
            if($2) {
		$packet_errors = $packet_errors + 1;
	    }
        }
    }

}

sub print_results {

    open OUT, ">meansoft-vs-ber.dat" || die "cant open dat file";
    for(my $i=0; $i<$numpkts; $i++) {
        print OUT $actual_bers[$i]." ".$projected_bers[$i]."\n";
    }

}


process_softphy();
print_results();
