#!/usr/bin/perl

$numArgs = $#ARGV + 1;

if ($numArgs < 3) {
    print "This program requires 3 arguments! Example usage:\n\t simScript.pl executable file_name_prefix no_files\n";
    exit 0;
}

for($i = 0; $i < $ARGV[2]; $i++)
{
    system "./plotImg.pl $ARGV[1]_$i.hex";
    system "mv $ARGV[1]_$i.hex.pdf ./samples_plot/";
    system "cp $ARGV[1]_$i.hex samples.hex";
    system "./$ARGV[0] > sim_result_$ARGV[1]_$i";
    system "./calculateSNR.pl $ARGV[1]_$i";
    system "./plotConstellation.pl $ARGV[1]_$i 64 48";
    system "./plotSynchronization.pl $ARGV[1]_$i";
    system "./plotBER.pl $ARGV[1]_$i";
    system "rm *.ps";
    system "mv constellation*.pdf ./constellation/";
    print "finish $i trace\n";
}



