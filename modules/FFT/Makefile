
THISDIR=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

CommonDir=../Common

S2H = FFTRequest
H2S = FFTIndication
BSVFILES = $(BsvFiles) $(CommonBsvFiles) src/FParams.bsv test/FFTInterface.bsv test/Top.bsv
CPPFILES=test/fft.cpp
NUMBER_OF_MASTERS =0
CONNECTALFLAGS += --bscflags=-p --bscflags=+:/scratch/jamey/airblue/modules/Parameters/WiFi:/scratch/jamey/airblue/modules/ShiftRegs/src:/scratch/jamey/airblue/modules/Types:/scratch/jamey/airblue/modules/Common

include $(CONNECTALDIR)/Makefile.connectal
