//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

import Vector::*;

interface RandomGen#(type sz);
    method ActionValue#(Bit#(sz)) genRand();
endinterface

module mkMersenneTwister#(Bit#(64) seed)(RandomGen#(64));
    
    Integer nn = 312;
    Integer m0 = 63;
    Integer m1 = 151;
    Integer m2 = 224;
    Bit#(64) matrixA = 64'hB3815B624FC82E2F;
    Bit#(64) umask = 64'hFFFFFFFF80000000;
    Bit#(64) lmask = 64'h7FFFFFFF;
    Bit#(64) maskB = 64'h599CFCBFCA660000;
    Bit#(64) maskC = 64'hFFFAAFFE00000000;
    Integer uu = 26;
    Integer ss = 17;
    Integer tt = 33;
    Integer ll = 39;

    Vector#(312, Reg#(Bit#(64))) mt = newVector();
    Bit#(64) seedVal = seed;
    for(Integer i = 0; i < nn; i=i+1)
    begin
        Bit#(32) ux = tpl_1(split(seedVal));
        seedVal = 2862933555777941757*seedVal+1;
        Bit#(32) lx = tpl_2(split(seedVal)); 
        seedVal = 2862933555777941757*seedVal+1;
        mt[i] <- mkReg(unpack({ux,lx}));
    end

    Reg#(UInt#(32)) mti <- mkReg(fromInteger(nn));

    method ActionValue#(Bit#(64)) genRand();
        let mtiRead = mti._read();
        if(mtiRead >= fromInteger(nn))
        begin
            for(Integer i = 0; i < nn-m2; i=i+1)
            begin
                let x = (mt[i]._read()&umask)|(mt[i+1]._read()&lmask);
                let temp = (x>>1) ^ ((x[0]==0)?0:matrixA);
                (mt[i]) <= mt[i]._read()^mt[(i+m0)%nn]._read()^mt[(i+m1)%nn]._read()^mt[(i+m2)%nn]._read();
            end
            mtiRead = 0;
        end
        mti <= mtiRead+1;
        let y = mt[mtiRead];
        y = y^(y>>uu);
        y = y^((y<<ss)&maskB);
        y = y^((y<<tt)&maskC);
        y = y^(y>>ll);
        return y;
    endmethod

endmodule
