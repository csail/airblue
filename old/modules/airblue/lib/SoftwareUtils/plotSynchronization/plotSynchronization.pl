#!/usr/bin/perl
$pos = 0;
$first_long_pos = 0;
$numArgs = $#ARGV + 1; # no arguments

if ($numArgs < 1) {
    print "This program needs an argument specifying the name of the file to which SNR results are written!\n";
    exit 0;
}

open(SIMRESULT,"<sim_result_$ARGV[0]");
open(SHORTFILE,">plot_short_sync.txt"); # open file
open(LONGFILE,">plot_long_sync.txt"); # open file

while(<SIMRESULT>) { # read one line from std_in a time
  chomp($_); # remove new line character

  if($_ !~ /PLOT/) { # doesn't match then jump to next iteration
#      print "jump";
      next;
  } 

  $pos++; # increase pos

  # short sync
  if (/SHORTSYNC/) {
      @values = split(/[\s]+/,$_); # split by at least one space character, idx 2 value = coarPow
      print SHORTFILE "$pos $values[2]\n";
  }

  # long sync
  if (/LONGSYNC/) {
      @values = split(/[:,\s]+/,$_);
      $long = hex($values[2]);
      if ($first_long_pos == 0) {
          $first_long_pos = $pos;
      }
      print LONGFILE "$pos $long\n";
  }
}

close SIMRESULT;
close SHORTFILE;
close LONGFILE;

if ($first_long_pos != 0)
{
    $first_long_pos = $first_long_pos - ($first_long_pos % 100);
    $start_x = $first_long_pos - 400;
    $end_x = $first_long_pos + 400;  
    open(PLOTFILE,">plotSynchronization.txt"); # open file
    
    print PLOTFILE "set xlabel \"Position\"\n";
    print PLOTFILE "set ylabel \"Short Preamble Correlation\"\n";
    print PLOTFILE "set y2label \"Long Preamble Correlation\"\n";
    print PLOTFILE "set size 1.0, 0.6\n";
    print PLOTFILE "set terminal postscript portrait enhanced color dashed lw 1 \"Helvetica\" 16\n"; 
    print PLOTFILE "set output \"my-plot.ps\"\n";
    print PLOTFILE "set xrange [$start_x:$end_x]\n";
    print PLOTFILE "set yrange [0:0.1]\n";
    print PLOTFILE "set y2range [0:60000000]\n";
    print PLOTFILE "set xtics nomirror\n";
    print PLOTFILE "set ytics nomirror\n";
    print PLOTFILE "set y2tics nomirror\n";
    print PLOTFILE "plot \"plot_short_sync.txt\" using 1:2 title \"Short Preamble Detection\" with points, \"plot_long_sync.txt\" using 1:2 title \"Long Preamble Detection\" lt 3 with points axes x1y2\n";

    close PLOTFILE;

    system "gnuplot plotSynchronization.txt";
    system "mv my-plot.ps ./sync_$ARGV[0].ps";
    system "ps2pdf sync_$ARGV[0].ps";
}
