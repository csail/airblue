#!/usr/bin/perl
$first = 1;
$numArgs = $#ARGV + 1; # no arguments

if ($numArgs < 2) {
    print "This program needs two arguments: 1) specifies the name of the output file, 2) specifies the size of FFT! Example usage\n";
    print "./packetHexToComplex.pl trace_name 64\n";
    exit 0;
}

$fft_n_minus_1 = $ARGV[1] - 1;
system "cat $ARGV[0].hex | ./packetHexToComplex > plot.txt"; 
open(INFILE,"<plot.txt");
open(OUTFILE,">$ARGV[0].m"); # generate matlab script

print OUTFILE "samples = [";

while(<INFILE>) {
    chomp($_); #remove new line character
    @values = split(/\s+/,$_); # split by at least one space character
    if ($first == 1) 
    {
        $first = 0;
    }
    else
    {
        print OUTFILE ", ";
    }
    print OUTFILE "$values[1]+$values[2]j";
}

print OUTFILE "]; \n";
print OUTFILE "resultvec = []; \n";
print OUTFILE "maxidx = length(samples); \n";
print OUTFILE "for i=1:maxidx-$fft_n_minus_1, \n";
print OUTFILE "temp = samples(i:i+$fft_n_minus_1); \n";
print OUTFILE "temp2 = abs(fftshift(fft(temp))); \n";
print OUTFILE "resultvec = cat(1,resultvec,temp2); \n";
print OUTFILE "end;\n";
#print OUTFILE "colormap(gray); \n"; # grey scale
#print OUTFILE "imagesc(transpose(resultvec)); \n"; # print 2D matrix as picture
print OUTFILE "gray = mat2gray(transpose(resultvec)); \n";
print OUTFILE "X = gray2ind(gray, 256); \n";
print OUTFILE "rgb = ind2rgb(X, hot(256)); \n";

print OUTFILE "imwrite(rgb, '$ARGV[0].jpg','jpg'); \n";
print OUTFILE "quit; \n";


close INFILE;
close OUTFILE;
