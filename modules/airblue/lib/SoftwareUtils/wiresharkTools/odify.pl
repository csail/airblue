#!/usr/bin/perl

chomp(@ARGV[0]);

`cat $ARGV[0] | ./samples $ARGV[0]`;
$count = 0;
$bytes = 0;
open(OUT,">$ARGV[0].od");
while(1){
  $result = `ls $ARGV[0]_samples_$count.hex 2> /dev/null`;
  print $result;
  if($result =~ /samples/) {
    open(IN,"< $ARGV[0]_samples_$count.hex ");
    while(<IN>) {
      chomp($_);
      printf OUT ("%x %x\n", $bytes, $_);
      $bytes = $bytes + 1; 
    }
    close(IN);
  }
  else {
    close(OUT);
    last;
  }

  $count = $count + 1;
}
