##----------------------------------------------------------------------##
## The MIT License 
## 
## Copyright (c) 2014 Quanta Resarch Cambridge, Inc.
## 
## Permission is hereby granted, free of charge, to any person 
## obtaining a copy of this software and associated documentation 
## files (the "Software"), to deal in the Software without 
## restriction, including without limitation the rights to use,
## copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the
## Software is furnished to do so, subject to the following conditions:
## 
## The above copyright notice and this permission notice shall be
## included in all copies or substantial portions of the Software.
## 
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
## EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
## OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
## NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
## HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
## WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
## FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
## OTHER DEALINGS IN THE SOFTWARE.
##----------------------------------------------------------------------##

THISDIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
MODULESDIR=$(realpath $(THISDIR)/..)

CommonDir=$(MODULESDIR)/Common

INTERFACES = FFTRequest FFTIndication
BSVFILES = $(BsvFiles) $(CommonBsvFiles) src/FParams.bsv test/FFTInterface.bsv test/Top.bsv
CPPFILES=test/fft.cpp
NUMBER_OF_MASTERS =0
CONNECTALFLAGS += --bscflags=-p --bscflags=+:$(MODULESDIR)/Parameters/WiFi:$(MODULESDIR)/ShiftRegs/src:$(MODULESDIR)/Types:$(MODULESDIR)/Common

dump:
	@echo $$\{THISDIR\} = ${THISDIR}
	@echo MODULESDIR = ${MODULESDIR}
	@echo $$\{CommonDir\} = ${CommonDir}
	@echo $(MAKEFILE_LIST)
	@echo $(firstword $(MAKEFILE_LIST))
	@echo $(realpath $(firstword $(MAKEFILE_LIST)))

include $(CONNECTALDIR)/Makefile.connectal
