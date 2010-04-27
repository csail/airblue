set terminal postscript eps color enhanced "Times-Roman" 32 

set xlabel "BER Estimate from SoftPHY Hints"
set ylabel "Actual BER of packet"

set log x
set log y
set xrange[0.001:0.5]
set yrange[0.001:0.5]

plot \
'meansoft-vs-ber.dat' u 1:2 pt 2 ps 1 t '', \
x lw 3 t 'y=x'

# 'meansoft-vs-ber-7.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-8.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-9.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-10.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-11.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-12.dat' u 1:2 pt 2 ps 1 t '', \
# 'meansoft-vs-ber-13.dat' u 1:2 pt 2 ps 1 t '', \
