# Build files
sim_top= MACCRCTest.bsv
BSVBLD = ../../build
RESDIR = ../../result

MAINV= ${BLUESPECDIR}/Verilog/main.v



src_dirs_plus= +:../../WiFiFPGA:$(src_dirs)

# have to go around a few times to build up the right arguments.  A terrible
# hack.

default:
	make default2 "BSVBLD = ../../../build" 

default2:
	export CXXFLAGS=
	make  build "BSVBLD = ../../../build" "src_dirs=$(src_dirs_plus)" "o_dir_bsim=../../../build/mkMACCRCTest/bo/" 

build: lib bsim


include ../../bsv.mk
