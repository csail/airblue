
THISDIR=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
MODULESDIR=$(THISDIR)/../..

CommonDir=$(MODULESDIR)/Common

S2H = ScramblerRequest
H2S = ScramblerIndication
BSVFILES = ScramblerTest.bsv Top.bsv
CPPFILES = scrambler.cpp
NUMBER_OF_MASTERS =0
CONNECTALFLAGS += --bscflags=-p --bscflags=+:$(MODULESDIR)/Parameters/WiFi:$(MODULESDIR)/ShiftRegs/src:$(MODULESDIR)/Types:$(MODULESDIR)/Common:$(MODULESDIR)/Scrambler/src

include $(CONNECTALDIR)/Makefile.connectal
