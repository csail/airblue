set terminal postscript eps color enhanced "Times-Roman" 32 

set xlabel "BER estimate from SoftPHY hints"
set ylabel "Ground truth BER"

set log xy
set xrange[0.001:1]
set yrange[0.001:1]

set format xy "10^{%L}"

plot \
'packet-ber.dat' using 1:2:3 with yerrorbars pt 2 ps 1 t '', \
x

# 'meansoft-vs-ber-7.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-8.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-9.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-10.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-11.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-12.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-13.dat' u 1:2 pt 2 ps 1 t '', \
