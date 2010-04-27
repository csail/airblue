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
my @meansoft_vals = ();
my @drops = ();

my $seedthresh = 5;

sub mean {
    my ($array_ref) = @_;
    my $sum = 0;
    foreach (@$array_ref) {
        $sum += $_;
    }
    return $sum / (scalar @$array_ref);
}

sub read_actual_bers {

    open BER, "$biterror_file" || die "cant open biterror file";

    while(my $line=<BER>) {
        if($line =~ m/PacketGen:\sPacket\sbit\serrors:\s+(\d+),.*length:\s(\d+)/) {
            #print "packet sz $2 bit erros $1\n";
            #if($2==$pktsz_bytes) {
                $numpkts++;
                my $actual_ber = $1/$pktsz_bits;
                push @actual_bers, $actual_ber;
            #}
        }

    }
    print "read $numpkts bers\n";
    #my $resp=<STDIN>;
}

sub process_softphy {

    my $unique_cnt = 0;

    open SOFTPHY, "$softphy_file" || die "cant open softphy";

    my @my_soft = ();
    my $my_pktcnt = 0;
    my $my_bitcnt = 0; 
    my $seedcheckcnt = 0;
    my $drop = 0;
    my $my_extrabits=0; 

    while(my $line = <SOFTPHY>) {
        if($line =~ m/report\smin\ssoftphy/) {

            my $meansoft = mean(\@my_soft);
            
            if($my_bitcnt == $pktsz_bits) {
                $my_pktcnt++;
                push @meansoft_vals, $meansoft;
                push @drops, $drop;
            }
            print "read $my_bitcnt bits, meansoft $meansoft, extras $my_extrabits\n";
            
            $my_bitcnt = 0; 
            @my_soft = ();
            $seedcheckcnt = 0;
            $drop = 0;     
            $my_extrabits=0; 
            
        }
        elsif($line =~ m/softphy\shints:\s+(\d+)/) {

            my $softval = $1/4;
        
            if($seedcheckcnt==16 && $my_bitcnt<$pktsz_bits) {
                $my_bitcnt++;
                my $pk = 1/(1+exp($softval));
                #print "$my_bitcnt $softval $pk\n";
                push @my_soft, $pk;
            }
            elsif($seedcheckcnt<16) { # check seed first 16 bits
                $seedcheckcnt++;
                #print "seed softval $softval\n";
                if($softval < $seedthresh) {
                    $drop = 1;
                }
            }
            else {
                $my_extrabits++;
            }

        }
    }

    print "read $my_pktcnt softphy hints\n";
    #my $resp=<STDIN>;
    #die if($my_pktcnt != $numpkts);

}

sub print_results {

    open OUT, ">meansoft-vs-ber.dat" || die "cant open dat file";
    my $maxi = $#meansoft_vals; #min2($#actual_bers, $#meansoft_vals);
    for(my $i=0; $i<=$maxi; $i++) {
        print OUT $actual_bers[$i]." ".$meansoft_vals[$i]." ".$drops[$i]."\n";# if($drops[$i]==0);
    }

    #system "gnuplot plot-ber.gp > meansoft-vs-ber.eps";
        
}

read_actual_bers();
process_softphy();
print_results();
