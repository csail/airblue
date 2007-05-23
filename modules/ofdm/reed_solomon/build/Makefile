#=======================================================================
# 6.375 Toplevel Makefile 
#-----------------------------------------------------------------------
# $Id: Makefile,v 1.1 2007/03/21 14:04:05 abhiag Exp $
#

default :

tools :=

#--------------------------------------------------------------------
# bsc-compile
#--------------------------------------------------------------------

.PHONY : bsc-compile

bsc-compile :
	cd bsc-compile; $(MAKE)

bsc-compile-clean :
	cd bsc-compile; make clean

tools += bsc-compile

#--------------------------------------------------------------------
# dc-synth
#--------------------------------------------------------------------

dc-synth : bsc-compile
	cd dc-synth; $(MAKE)

dc-synth-clean :
	cd dc-synth; make clean

tools += dc-synth

#--------------------------------------------------------------------
# enc-fp
#--------------------------------------------------------------------

enc-fp : dc-synth
	cd enc-fp; $(MAKE)

enc-fp-clean :
	cd enc-fp; make clean

tools += enc-fp

#--------------------------------------------------------------------
# enc-par
#--------------------------------------------------------------------

enc-par : dc-synth enc-fp
	cd enc-par; $(MAKE)

enc-par-clean :
	cd enc-par; make clean

tools += enc-par


#--------------------------------------------------------------------
# vcs-sim-rtl
#--------------------------------------------------------------------

.PHONY : vcs-sim-rtl

vcs-sim-rtl : bsc-compile
	cd vcs-sim-rtl; $(MAKE)

vcs-sim-rtl-clean :
	cd vcs-sim-rtl; make clean

run-asm-tests : vcs-sim-rtl
	cd vcs-sim-rtl; $(MAKE) run-asm-tests

run-bmarks-smips : vcs-sim-rtl
	cd vcs-sim-rtl; $(MAKE)	 run-bmarks-smips

tools += vcs-sim-rtl

#--------------------------------------------------------------------
# clean
#--------------------------------------------------------------------

clean :
	@echo ""; \
	echo -n "  Are you sure you want to do a FULL clean? [Y/N] "; \
	read ans; \
	if [ "$$ans" == "Y" ]; \
	then \
	  for tool in $(tools); \
	  do \
        cd $$tool; make clean; cd ..; \
	  done; \
	fi; \
	echo ""; 
