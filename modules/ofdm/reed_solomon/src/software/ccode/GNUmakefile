CC= g++
RM= rm
SHARED_OBJECT_FLAG = -shared

DEBUG = -ggdb
OPTIMIZE = -O3
CXXFLAGS = -I$(INC_PATH) -Wall -ggdb

build:  preproc

preproc: preproc.o
	$(CXX) -o preproc preproc.o

gfarith: 
	$(CXX) -c -o gfarith.o gfarith.cpp

reedsolomon: reedsolomon.o
	$(CXX) -o reedsolomon reedsolomon.o

rs256: rs256.o
	$(CXX) -o rs256 rs256.o

syndrome: syndrome.o gfarith.o
	$(CXX) -o syndrome syndrome.o gfarith.o



berl: berl.o gfarith.o
	$(CXX) -o  berl berl.o gfarith.o

chien: chien.o
	$(CXX) -o  chien chien.o 

chien_errmag: chien_errmag.o gfarith.o
	$(CXX) -o  chien_errmag chien_errmag.o gfarith.o

testrs: rs256.o
	rm -f test
	rs256 > test

testsyn:
	rm -f syn1
	syndrome input.dat > syn1

testberl:
	rm -f berl1
	berl synmsg > berl1
	vim berl1

testchien_errmag:
	rm -f chien_errmag1
	chien_errmag berlmsg berlmsg2 input.dat > chien_errmag1

testchien: 
	rm -f chien1
	chien berlmsg > chien1

