function out = Interleaver(bits, modulation)
    switch modulation
        case 'BPSK'
            cbps = 48;
        case 'QPSK'
            cbps = 96;
        case 'QAM16'
            cbps = 192;
        case 'QAM64'
            cbps = 288;
    end

    bpsc = cbps / 48;
    s = max(bpsc / 2, 1);
    
    L = length(bits);
    bits = reshape(bits, cbps, L/cbps);
    k = 0:cbps-1;
    
    i = (cbps / 16) * mod(k, 16) + floor(k / 16);
    j = s * floor(i / s) + mod(i + cbps - floor(16 * i / cbps), s);
    
    out(j + 1,:) = bits;
    out = reshape(out, 1, L);
end