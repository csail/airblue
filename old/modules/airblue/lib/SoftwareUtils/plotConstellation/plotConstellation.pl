#!/usr/bin/perl
$in = 0;
$out = 0;
$symNum = 0;

while(<>) {
  chomp($_);
   
  if(($_ !~ /^ChannelEstIn/) && ($_ !~ /^ChannelEstOut/)) {
    next;
  } 

  if(($in == 0) && ($out == 0)) {
    print "opening\n";
    open(PILOTS,">./pilots_$symNum.txt");
    open(PRESUBCARRIER, ">./presubcarriers_$symNum.txt");
    open(ALL,">./all_$symNum.txt");
    open(POSTSUBCARRIER, ">./postsubcarriers_$symNum.txt");
  }

  @values = split(/[i\s]+/,$_);
  print $values[3] . "\n";
   if(($in < 64) && ($_ != /^ChannelEstIn/) ) {
      print ALL "$values[2] $values[4]\n";
      if( $in == 11 || $in == 25 || $in == 39 || $in == 53) {
        print PILOTS "$values[2] $values[4]\n";
      } elsif($in > 5 && $in < 59) {
        print PRESUBCARRIER "$values[2] $values[4]\n";
      }
     $in++;
   } elsif(($out < 48) && ($_ != /^ChannelEstOut/)) {
      print POSTSUBCARRIER "$values[3] $values[5]\n";
     $out++;
   } 

   if($out == 48 && $in == 64) {
     close ALL;
     close PRESUBCARRIER;
     close PILOTS;
     close POSTSUBCARRIER;
     $out = 0;
     $in = 0;
     $symNum++;
   }
}


#Now, setup the files

for($i = 0; $i < $symNum; $i++) {
   print "pilots_$i.txt\n";
  `cp ./pilots_$i.txt plot.txt`;
  `gnuplot plotConstellation.txt`;
  `cp my-plot.ps ./pilots_$i.ps`;
   print "presubcarriers_$i.txt\n";
  `cp ./presubcarriers_$i.txt plot.txt`;
  `gnuplot plotConstellation.txt`;
  `cp my-plot.ps ./presubcarriers_$i.ps`;
   print "all_$i.txt\n";
  `cp ./all_$i.txt plot.txt`;
  `gnuplot plotConstellation.txt`;
  `cp my-plot.ps ./all_$i.ps`;
   print "postsubcarriers_$i.txt\n";
  `cp ./postsubcarriers_$i.txt plot.txt`;
  `gnuplot plotConstellation.txt`;
  `cp my-plot.ps ./postsubcarriers_$i.ps`;
}
