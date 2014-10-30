
THISDIR=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
MODULESDIR=$(THISDIR)/..

CommonDir=$(MODULESDIR)/Common

S2H = FFTRequest
H2S = FFTIndication
BSVFILES = $(BsvFiles) $(CommonBsvFiles) src/FParams.bsv test/FFTInterface.bsv test/Top.bsv
CPPFILES=test/fft.cpp
NUMBER_OF_MASTERS =0
CONNECTALFLAGS += --bscflags=-p --bscflags=+:$(MODULESDIR)/Parameters/WiFi:$(MODULESDIR)/ShiftRegs/src:$(MODULESDIR)/Types:$(MODULESDIR)/Common

include $(CONNECTALDIR)/Makefile.connectal
