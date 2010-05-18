set terminal postscript eps color enhanced "Times-Roman" 32 

set xlabel "SoftPHY Hints"
set ylabel "Error Percentage"

set log y
set xrange[64:0]
set yrange[0.000001:1]

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
