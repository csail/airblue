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
