#=======================================================================
# 6.375 Makefile for bsc-compile
#-----------------------------------------------------------------------
# $Id: Makefile,v 1.2 2007/04/25 00:59:41 abhiag Exp $
#

default : symlinks all

basedir  = ../..

#--------------------------------------------------------------------
# Sources
#--------------------------------------------------------------------


# Bluespec sources

toplevel_module = mkReedSolomon

srcdir = $(basedir)/src/bluespec
bsvsrcs = \
	$(srcdir)/Types.bsv \
        $(srcdir)/Arith.bsv \
        $(srcdir)/SyndromeParallel.bsv \
        $(srcdir)/Berlekamp.bsv \
        $(srcdir)/ChienErrMag.bsv \
        $(srcdir)/ErrorCorrector.bsv \
        $(srcdir)/IReedSolomon.bsv \
        $(srcdir)/mkReedSolomon.bsv \

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

symlinks:
	unlink $(srcdir)/ChienErrMag.bsv
	ln -s $(srcdir)/ChienErrMag_locFIFO.bsv $(srcdir)/ChienErrMag.bsv

BSC_COMP = bsc

BSC_OPTS = -u -show-module-use -verilog -keep-fires -relax-method-earliness -aggressive-conditions

# Copy over the bluespec source

$(notdir $(bsvsrcs)) : % : $(srcdir)/%
	cp $< .

# Run the bluespec compiler

bsv_TH_vsrc = $(toplevel_module).v
$(bsv_TH_vsrc) $(bsv_lib_use) : $(notdir $(bsvsrcs) $(bsvclibsrcs))
	$(BSC_COMP) $(BSC_OPTS) -g $(toplevel_module) $(toplevel_module).bsv

compile : $(toplevel_module).v

# Create a schedule file

schedule_rpt = schedule.rpt
$(schedule_rpt) : $(notdir $(bsvsrcs) $(bsvclibsrcs))
	rm -rf *.v
	$(BSC_COMP) $(BSC_OPTS) -show-schedule -show-rule-rel \* \* -g $(toplevel_module) \
                $(toplevel_module).bsv >& $(schedule_rpt)

junk += $(notdir $(bsvsrcs)) $(notdir $(bsvclibsrcs)) \
	    $(schedule_rpt) *.use *.bi *.bo *.v bsc.log

#--------------------------------------------------------------------
# Default make target
#--------------------------------------------------------------------

all : compile

#--------------------------------------------------------------------
# Clean up
#--------------------------------------------------------------------

clean :
	rm -rf $(junk) *~ \#* 
