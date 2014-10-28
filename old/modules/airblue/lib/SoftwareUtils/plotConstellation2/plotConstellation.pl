#!/usr/bin/perl
$in = 0;
$out = 0;
$symNum = 0;
$numArgs = $#ARGV + 1; # no arguments
$packetNum = 0;
$string = "";

if ($numArgs < 3) {
    print "This program requires 3 arguments! Example usage:\n\t plotConstellation.pl file_name no_input_channels no_out_channels\n";
    exit 0;
}

open(SIMRESULT,"<./sim_result_$ARGV[0]");

while(<SIMRESULT>) {
  chomp($_);
   
  if(($_ !~ /^ChannelEstIn/) && ($_ !~ /^ChannelEstOut/)
     && ($_ !~ /new\smessage:1/) && ($_ !~ /interpolate angle/) 
     && ($_ !~ /interpolate mag/)) {
    next;
  } 

  if (/new\smessage:1/) {
      if ($packetNum > 0) {
          $string = "";
          for ($i = 1; $i <= $symNum; $i++) {
              $string = $string." constellation_$ARGV[0]_pkt_$packetNum\_sym_$i.pdf ";
          }
          system "pdftk $string cat output constellation_$ARGV[0]_pkt_$packetNum.pdf";
          system "rm constellation_$ARGV[0]_pkt_$packetNum\_sym_*.ps";
          system "rm constellation_$ARGV[0]_pkt_$packetNum\_sym_*.pdf";
      }
      $packetNum++;
      $symNum = 0;
      print "processing $packetNum\n";
      next;
  }

  if ($out == 0 && $in == 0) {
      open(PILOTANGLES,">./pilotangles.txt");
      open(PILOTMAGS,">./pilotmags.txt");
      open(PRESUBCARRIER, ">./presubcarriers.txt");
      open(POSTSUBCARRIER, ">./postsubcarriers.txt");
  }

  @values = split(/[i\s]+/,$_);

  if (/interpolate angle/) {
      print PILOTANGLES "$values[4] $values[5]\n";
  }      

  if (/interpolate mag/) {
      print PILOTMAGS "$values[5] $values[6]\n";
  }      

   if(($in < $ARGV[1]) && ($_ != /^ChannelEstIn/) ) {
#      print ALL "$values[2] $values[4]\n";
#      if( $in == 11 || $in == 25 || $in == 39 || $in == 53) {
#        print PILOTS "$values[2] $values[4]\n";
#      } elsif($in > 5 && $in < 59) {
        print PRESUBCARRIER "$values[2] $values[4]\n";
#      }
     $in++;
   } elsif(($out < $ARGV[2]) && ($_ != /^ChannelEstOut/)) {
      print POSTSUBCARRIER "$values[3] $values[5]\n";
     $out++;
   } 

   if($out == $ARGV[2] && $in == $ARGV[1]) {
       $symNum++;
       $out = 0;
       $in = 0;
#       close ALL;
       close PRESUBCARRIER;
#       close PILOTS;
       close PILOTANGLES;
       close PILOTMAGS;
       close POSTSUBCARRIER;
#       system "cp ./pilots.txt plot.txt";
       system "gnuplot plotConstellation.txt";
       system "cp my-plot.ps ./constellation_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
       system "ps2pdf constellation_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
#        system "cp ./presubcarriers.txt plot.txt";
#        system "gnuplot plotConstellation.txt";
#        system "cp my-plot.ps ./presubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
#        system "ps2pdf presubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
#        system "cp ./all.txt plot.txt";
#        system "gnuplot plotConstellation.txt";
#        system "cp my-plot.ps ./all_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
#        system "ps2pdf all_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
#        system "cp ./postsubcarriers.txt plot.txt";
#        system "gnuplot plotConstellation.txt";
#        system "cp my-plot.ps ./postsubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
#        system "ps2pdf postsubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
   }
}

close SIMRESULT;
#close ALL;
close PRESUBCARRIER;
#close PILOTS;
close PILOTANGLES;
close PILOTMAGS;
close POSTSUBCARRIER;
system "rm constellation_$ARGV[0]_pkt_$packetNum\_sym_*.ps";
system "rm constellation_$ARGV[0]_pkt_$packetNum\_sym_*.pdf";
#system "cp ./pilots.txt plot.txt";
# system "gnuplot plotConstellation.txt";
# system "cp my-plot.ps ./constellation_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf constellation_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "cp ./presubcarriers.txt plot.txt";
# system "gnuplot plotConstellation.txt";
# system "cp my-plot.ps ./presubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf presubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "cp ./all.txt plot.txt";
# system "gnuplot plotConstellation.txt";
# system "cp my-plot.ps ./all_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf all_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "cp ./postsubcarriers.txt plot.txt";
# system "gnuplot plotConstellation.txt";
# system "cp my-plot.ps ./postsubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "ps2pdf postsubcarriers_$ARGV[0]_pkt_$packetNum\_sym_$symNum.ps";
# system "rm *.ps";
# system "cp *.pdf constellation/"; 

