# $Id: makefile,v 1.1.1.1 2007/07/27 20:37:37 mng Exp $
# ------------------------------------------------------

# Build files
sim_top= BCJRTest.bsv
BSVBLD = ../../../../build
cleanBLD = ../../../../build
mkSimTop = $(sim_top:%.bsv=mk%)
RESDIR = ../../../../result
c_files = ../common/addError.c

#dut_files = ZtideTop.bsv

MAINV= ${BLUESPECDIR}/Verilog/main.v



src_dirs_plus= +:../../../WiFi:../../:../../Puncturer:../../FIFOs:../../Mapper:../../ConvEncoder:::../common:$(src_dirs)

# have to go around a few times to build up the right arguments.  A terrible
# hack.

default:
	make default2 "BSVBLD=../../../../build"  #"BLD=../../../../build"


default2:
	export CXXFLAGS=
	make  build "BSVBLD=../../../../build" "src_dirs=$(src_dirs_plus)" "o_dir_bsim=$(o_dir)" "lib_dir=../../" #"BLD=../../../../build"

build: lib bsim

#clean is busted
include ../../../bsv.mk

clean:
	rm -rf $(cleanBLD)/$(mkSimTop)
	rm -f mk*V
	rm -f mk*BA