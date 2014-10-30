
THISDIR=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
MODULESDIR=$(THISDIR)/../..

CommonDir=$(MODULESDIR)/Common

S2H = ConvEncoderRequest
H2S = ConvEncoderIndication
BSVFILES = ConvEncoderTest.bsv Top.bsv
CPPFILES = convencoder.cpp
NUMBER_OF_MASTERS =0
CONNECTALFLAGS += --bscflags=-p --bscflags=+:$(MODULESDIR)/Parameters/WiFi:$(MODULESDIR)/ShiftRegs/src:$(MODULESDIR)/Types:$(MODULESDIR)/Common:$(MODULESDIR)/ConvEncoder/src

include $(CONNECTALDIR)/Makefile.connectal
