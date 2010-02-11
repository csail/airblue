#!/usr/bin/perl
$packetNum = 0; # packet no
$m = 0;
$snr = 0;
$scaling = 0;
$expected = 0.201962868; # expected power of short symbol
$numArgs = $#ARGV + 1; # no arguments
$fineTimeCorrPow = 0;
$fineTimePowSq = 0;

if ($numArgs < 1) {
    print "This program needs an argument specifying the name of the file to which SNR results are written!\n";
    exit 0;
}

open(SIMRESULT,"<sim_result_$ARGV[0]");
open(SNRFILE,">snr_$ARGV[0]"); # open file

while(<SIMRESULT>) { # read one line from std_in a time
  chomp($_); # remove new line character

  if(($_ !~ /SHORTSYNC/) &&
     ($_ !~ /maxFineTimePosSq:/)) { # doesn't match then jump to next iteration
#      print "jump";
      next;
  } 

  # short sync
  if (/SHORTSYNC/) {
      @values = split(/[\s]+/,$_); # split by at least one space character, idx 2 value = coarPow
      $scaling = $values[2]/$expected; # get the scaling required for long sync
  }

  # long sync
  if (/maxFineTimePosSq:/) {
      @values = split(/[:,\s]+/,$_);
      $fineTimeCorrPow = hex($values[2]);
      $fineTimePowSq = hex($values[4]);
      if ($fineTimeCorrPow < $fineTimePowSq) { # doesn't pass the threshold yet
          next;
      }
      $m = sqrt($fineTimeCorrPow/($fineTimePowSq*2*$scaling));
      if ($m < 1) {
          $snr = 10*(log($m/(1-$m))/log(10));
      }
      else {    
          $snr = 50;
      }
      print SNRFILE "SNR of $packetNum packet = $snr\n";
      $packetNum++;
  }
}

close SIMRESULT;
close SNRFILE;
