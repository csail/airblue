#!/usr/bin/perl
$in = $ARGV[1];
$out = 0;
$symNum = 0;
$numArgs = $#ARGV + 1; # no arguments
$packetNum = 0;
$string = "";

if ($numArgs < 2) {
    print "This program requires 2 arguments! Example usage:\n\t plotPower.pl file_name no_input_channels\n";
    exit 0;
}

open(SIMRESULT,"<./sim_result_$ARGV[0]");

while(<SIMRESULT>) {
  chomp($_);
   
  if(($_ !~ /^ChannelEstIn/) && ($_ !~ /new\smessage:1/)) {
    next;
  } 

  if (/new\smessage:1/) {
      $packetNum++;
      $in = 0;
      print "processing $packetNum\n";
      open(PRESUBCARRIER, ">./presubcarriers.txt");
      next;
  }

  @values = split(/[i\s]+/,$_);

  if(($in < $ARGV[1]) && ($_ != /^ChannelEstIn/) ) {
#      print ALL "$values[2] $values[4]\n";
#      if( $in == 11 || $in == 25 || $in == 39 || $in == 53) {
#        print PILOTS "$values[2] $values[4]\n";
#      } elsif($in > 5 && $in < 59) {
      $power = $values[2]*$values[2] + $values[4]*$values[4];
      $carr  = $in - 32; # carrier idx
      print PRESUBCARRIER "$carr $power \n";
#      print "$carr $power $values[2] $values[4]\n";
#      }
      $in++;
      if($in == $ARGV[1]) {
          close PRESUBCARRIER;
          system "gnuplot plotPower.txt";
          system "cp my-plot.ps ./power_$ARGV[0]_pkt_$packetNum.ps";
          system "ps2pdf power_$ARGV[0]_pkt_$packetNum.ps";
      }
  } 

}

close SIMRESULT;
#close ALL;
close PRESUBCARRIER;
#close PILOTS;
#close PILOTANGLES;
#close PILOTMAGS;
#close POSTSUBCARRIER;
system "rm -f power_$ARGV[0]_pkt_$packetNum\_sym_*.ps";
system "rm -f power_$ARGV[0]_pkt_$packetNum\_sym_*.pdf";
#system "cp ./pilots.txt plot.txt";
# system "gnuplot plotPower.txt";
# system "cp my-plot.ps ./power_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf power_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "cp ./presubcarriers.txt plot.txt";
# system "gnuplot plotPower.txt";
# system "cp my-plot.ps ./presubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf presubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "cp ./all.txt plot.txt";
# system "gnuplot plotPower.txt";
# system "cp my-plot.ps ./all_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf all_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "cp ./postsubcarriers.txt plot.txt";
# system "gnuplot plotPower.txt";
# system "cp my-plot.ps ./postsubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf postsubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "rm *.ps";
# system "cp *.pdf power/"; 

