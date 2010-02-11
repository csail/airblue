#!/usr/bin/perl

$numArgs = $#ARGV + 1; # no arguments

if ($numArgs < 3) {
    print "This program needs three arguments: 1) specifies the prefix of the traces 2) specifies FFT size 3) specifies the number of traces";
    print "./runScript trace_name_prefix fft_size no_traces\n";
    exit 0;
}

for ($i = 0; $i < $ARGV[2]; $i++)
{
    print "processing trace $i\n";
    system "./packetHexToComplex.pl $ARGV[0]_$i $ARGV[1]";
    system "matlab -nodesktop -nodisplay -r $ARGV[0]_$i";
    system "convert -filter point -resize 816x640\\! $ARGV[0]_$i.jpg $ARGV[0]_$i.jpg";
}
# $fft_n_minus_1 = $ARGV[1] - 1;
# system "cat $ARGV[0].hex | ./packetHexToComplex > plot.txt"; 
# open(INFILE,"<plot.txt");
# open(OUTFILE,">$ARGV[0].m"); # generate matlab script

# print OUTFILE "samples = [";

# while(<INFILE>) {
#     chomp($_); #remove new line character
#     @values = split(/\s+/,$_); # split by at least one space character
#     if ($first == 1) 
#     {
#         $first = 0;
#     }
#     else
#     {
#         print OUTFILE ", ";
#     }
#     print OUTFILE "$values[1]+$values[2]j";
# }

# print OUTFILE "]; \n";
# print OUTFILE "resultvec = []; \n";
# print OUTFILE "maxidx = length(samples); \n";
# print OUTFILE "for i=1:maxidx-$fft_n_minus_1, \n";
# print OUTFILE "temp = samples(i:i+$fft_n_minus_1); \n";
# print OUTFILE "temp2 = abs(fftshift(fft(temp))); \n";
# print OUTFILE "resultvec = cat(1,resultvec,temp2); \n";
# print OUTFILE "end;\n";
# print OUTFILE "colormap(gray)\n"; # grey scale
# print OUTFILE "imagesc(transpose(resultvec))\n"; # print 2D matrix as picture  

# close INFILE;
# close OUTFILE;
