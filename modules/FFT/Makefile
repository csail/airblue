
CommonDir=../Common
CommonBsvFiles = ../ShiftRegs/src/ShiftRegs.bsv ../Types/AirblueTypes.bsv $(CommonDir)/FPComplex.bsv

S2H = FFTRequest
H2S = FFTIndication
BSVFILES = $(BsvFiles) $(CommonBsvFiles) TestParams.bsv src/FParams.bsv src/FFTInterface.bsv Top.bsv
CPPFILES=testfft.cpp
NUMBER_OF_MASTERS =0

include $(CONNECTALDIR)/Makefile.connectal
