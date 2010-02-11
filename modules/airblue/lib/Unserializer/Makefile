# $Id: makefile,v 1.1.1.1 2007/07/27 20:37:37 mng Exp $
# ------------------------------------------------------

# Build files
sim_top= UnserializerTest.bsv
BSVBLD = ../../build
RESDIR = ../../result

#dut_files = ZtideTop.bsv

MAINV= ${BLUESPECDIR}/Verilog/main.v



src_dirs_plus= +:../../WiFi:$(src_dirs)

# have to go around a few times to build up the right arguments.  A terrible
# hack.

default:
	make default2 "BSVBLD = ../../../build" 

default2:
	export CXXFLAGS=
	make  build "BSVBLD = ../../../build" "src_dirs=$(src_dirs_plus)" "o_dir_bsim=$(o_dir)" 

build: lib bsim


include ../../bsv.mk
