#=======================================================================
# Makefile for imdct testbench
#-----------------------------------------------------------------------

default : symlinks mkTestBench

#--------------------------------------------------------------------
# Sources
#--------------------------------------------------------------------

# Library components

bsvclibdir = $(MIT6375_HOME)/install/bsvclib
bsvclibsrcs = \

# Bluespec sources

srcdir  = ../../src/bluespec

topdir  = ../../..

toplevel_module = mkTestBench

bsvsrcs = \
	$(srcdir)/Types.bsv \
        $(srcdir)/Arith.bsv \
        $(srcdir)/SyndromeParallel.bsv \
        $(srcdir)/Berlekamp.bsv \
        $(srcdir)/ChienErrMag.bsv \
        $(srcdir)/ErrorCorrector.bsv \
        $(srcdir)/IReedSolomon.bsv \
        $(srcdir)/mkReedSolomon.bsv \
        $(srcdir)/mkTestBench.bsv \
        $(srcdir)/file_interface.cpp \
  
topsrcs = \

cppdir = ../../src/software/ccode

cppsrcs = $(cppdir)/preproc.cpp

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

# copy over, compile & run the preproc to generate the GF inverse logic.
$(notdir $(cppsrcs)) : % : $(cppdir)/%
	cp $< .

preproc.o : $(notdir $(cppsrcs))
	$(CXX) -c -o preproc.o preproc.cpp

preproc : preproc.o
	$(CXX) -o preproc preproc.o

GFInv.bsv : preproc $(notdir $(bsvsrcs))
	./preproc mkTestBench.bsv GFInv.bsv
	cat GFInv.bsv >> Arith.bsv
	rm -f GFInv.bsv


symlinks:
	rm -f Arith.bsv

BSC_COMP = bsc

BSC_OPTS = -u -sim -steps-warn-interval 200000 -steps-max-intervals 10

# Copy over the bluespec source

$(notdir $(bsvsrcs)) : % : $(srcdir)/%
	cp $< .

$(notdir $(topsrcs)) : % : $(topdir)/%
	cp $< .

$(notdir $(bsvclibsrcs)) : % : $(bsvclibdir)/%
	cp $< .

# run gcc

file_interface.o : file_interface.cpp
	gcc -c -DDATA_FILE_PATH=\"../output/input.dat\" \
	       -DOUT_DATA_FILE_PATH=\"../output/output.dat\" \
		file_interface.cpp

# Run the bluespec compiler

mkTestBench.ba : GFInv.bsv $(notdir $(topsrcs) $(bsvsrcs) $(bsvclibsrcs))
	$(BSC_COMP) $(BSC_OPTS) -g mkTestBench mkTestBench.bsv

mkTestBench : mkTestBench.ba file_interface.o
	$(BSC_COMP) $(BSC_OPTS) -e $(toplevel_module) *.ba file_interface.o
	mv a.out bsim
	rm -f bsim.out


# Create a schedule file

schedule_rpt = schedule.rpt
$(schedule_rpt) : $(notdir $(bsvsrcs) $(bsvclibsrcs))
	rm -rf *.v
	$(BSC_COMP) $(BSC_OPTS) -show-schedule -show-rule-rel \* \* -g $(toplevel_module) $(toplevel_module).bsv

#	$(BSC_COMP) $(BSC_OPTS) -show-schedule -show-rule-rel \* \* -g $(toplevel_module) \
#				$(toplevel_module).bsv >& $(schedule_rpt)

#--------------------------------------------------------------------
# Clean up
#--------------------------------------------------------------------

junk += $(notdir $(bsvsrcs))  $(notdir $(bsvclibsrcs)) \
	    $(schedule_rpt) *.use *.bi *.bo *.v bsc.log \
	    $(notdir $(topsrcs))  $(notdir $(cppsrcs)) \
		 preproc*

.PHONY: clean

clean :
	rm -rf $(junk) *~ \#* *.h *.o *.cxx *.ba a.out bsim

