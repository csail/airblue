#!/usr/bin/perl
use Switch

$in = $ARGV[1];
$out = 0;
$symNum = 0;
$numArgs = $#ARGV + 1; # no arguments
$packetNum = 0;
$string = "";
@fields;
$base = 0;

if ($numArgs < 1) {
    print "This program requires 1 argument! Example usage:\n\t extractPacketInfo.pl file_name\n";
    exit 0;
}

open(SIMRESULT,"<./$ARGV[0]");
open(PROCESSFILE, ">./extract_packet_$ARGV[0]");

while(<SIMRESULT>) {
  chomp($_);   

  if(($_ !~ /PreDescramblerRXCtrllr/) && ($_ !~ /CRC/) && ($_ !~ /Src:/)) {
    next;
  } else
  {
      if (/PreDescramblerRXCtrllr/) {
          $packetNum++;
          $base = ($packetNum - 1) * 5;
          for ($i = 0; $i < 5; $i++) {
              $fields[$base + $i] = "";
          }
          my @splitted = split;
          if (/error/) {
              $fields[$base + 0] = "PHYHeaderError";
              $fields[$base + 1] = "Rate: $splitted[21]"; # rate
              $fields[$base + 2] = "Length: $splitted[19]"; # length
          } else {
              switch ($splitted[6]) { # rate
                  case "000" { $fields[$base + 1] = "Rate: 6Mbps"}
                  case "001" { $fields[$base + 1] = "Rate: 9Mbps"}
                  case "010" { $fields[$base + 1] = "Rate: 12Mbps"}
                  case "011" { $fields[$base + 1] = "Rate: 18Mbps"}
                  case "100" { $fields[$base + 1] = "Rate: 24Mbps"}
                  case "101" { $fields[$base + 1] = "Rate: 36Mbps"}
                  case "110" { $fields[$base + 1] = "Rate: 48Mbps"}
                  case "111" { $fields[$base + 1] = "Rate: 54Mbps"}
              }
              $fields[$base + 2] = "Length: $splitted[8]";
          }
      } else {
          if (/CRC/) {
              if (/non-matching/) {
                  $fields[$base + 0] = "MACNonMatchCRC";
              } else {
                  $fields[$base + 0] = "MACMatchCRC";
              }
          } else {
              my @splitted = split;
              $splitted[2] =~ s/,//;
              $fields[$base + 3] = "Src: $splitted[2]";
              $fields[$base + 4] = "Dest: $splitted[4]";
          }
      }
  }

}

print "$#packetinfo\n";

for ($i = 0; $i < $packetNum; $i++) {
    print "$i\t";
    for ($j = 0; $j < 5; $j++) {
        print "$fields[$i*5+$j]\t";
    }
    print "\n";
}


close SIMRESULT;
close PROCESSFILE;

