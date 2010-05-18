#!/usr/bin/perl


@files = `find | grep meansoft | grep raw`;
@dirs = `find | grep plot-ber`;

`rm  meansoft-vs-ber.dat`;
#aggregate rate datas
@rate_total_bits = ();
@rate_error_bits = ();

for($rate = 0; $rate < 8; $rate = $rate + 1) {
    $rate_total_bits[$rate] = ();
    $rate_error_bits[$rate] = ();
    for($bins = 0; $bins < 256; $bins = $bins + 1) {
	$rate_total_bits[$rate][$bins] = 0;
	$rate_error_bits[$rate][$bins] = 0;
    }
}

foreach $file (@files) {
   chomp($file);
   open(DATA,"<$file");
   $bin = 0;
   $rate = 0;
   if($file =~ /ratio_rate_(\d+)_snr/) {
       $rate = $1;
       print "setting rate $rate for $file\n";
   }
   while(<DATA>) {
       #figure out the rate 
       if($_ =~ /(\d+)\s+(\d+)/){
	   $rate_total_bits[$rate][$bin] = $rate_total_bits[$rate][$bin] + $2;
	   $rate_error_bits[$rate][$bin] = $rate_error_bits[$rate][$bin] + $1;
           $bin = $bin + 1;
       }
   }


}

#dump total
open(ALL_DATA,">allrates.raw");
open(ALL_COOKED,">allrates.dat");

for($bins = 0; $bins < 256; $bins = $bins + 1) {
    $total_bits = 0;
    $error_bits = 0;

    for($rate = 0; $rate < 8; $rate = $rate + 1) {
        $total_bits = $total_bits + $rate_total_bits[$rate][$bins];
        $error_bits = $error_bits + $rate_error_bits[$rate][$bins];
    }
    close(RATE_DATA);    
    if($total_bits == 0) {
        $ratio = 0;
    } else {
        $ratio = $error_bits/$total_bits;
    }

    print ALL_DATA "$error_bits $total_bits\n";
    print ALL_COOKED "$bins $ratio\n";
}
close(ALL_DATA);    

for($rate = 0; $rate < 8; $rate = $rate + 1) {
    open(RATE_DATA,">rate${rate}.raw");
    open(RATE_COOKED,">rate${rate}.dat");
    for($bins = 0; $bins < 256; $bins = $bins + 1) {

        $total = $rate_total_bits[$rate][$bins];
        $error = $rate_error_bits[$rate][$bins];
	if($total == 0) {
	    $ratio = 0;
	} else {
            $ratio = $error/$total;
        }

        print RATE_DATA "$error $total\n";
        print RATE_COOKED "$bins $ratio\n";
    }
    close(RATE_DATA);
}



chomp($dirs[0]);
print "$dirs[0]\n";

#run the gnuplot
`cp allrates.dat meansoft-vs-ber.dat`;
`gnuplot $dirs[0] > all.eps`; 


for($rate = 0; $rate < 8; $rate = $rate + 1) {
     `cp rate${rate}.dat meansoft-vs-ber.dat`;
    `gnuplot $dirs[0] > rate${rate}.eps`; 
}

`echo "BER v. Softhint Bin" | mutt -s graph -a *.eps -- \$USER > mutt.txt`;  

