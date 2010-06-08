function out = Deinterleaver(bits, modulation)
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
    j = 0:cbps-1;
    
    i = s * floor(j / s) + mod(j + floor(16 * j / cbps), s);
    k = (16 * i) - (cbps - 1) * floor(16 * i / cbps);
    
    out(k + 1,:) = bits;
    out = reshape(out, 1, L);
end