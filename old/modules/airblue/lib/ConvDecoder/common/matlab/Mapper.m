function syms = Mapper(bits, modulation)
    switch modulation
        case 'BPSK'
            syms = Map_BPSK(bits);
        case 'QPSK'
            syms = Map_QPSK(bits);
        case 'QAM16'
            syms = Map_QAM16(bits);
        case 'QAM64'
            syms = Map_QAM64(bits);
    end
end

function syms = Map_BPSK(bits)
    h = modem.qammod('M', 2, 'SymbolOrder', 'gray', 'InputType', 'bit');
    syms = modulate(h, bits);
end

function syms = Map_QPSK(bits)
    h = modem.qammod('M', 4, 'SymbolOrder', 'gray', 'InputType', 'bit');
    syms = modulate(h, reshape(bits, 2, length(bits) / 2));
    syms = conj(syms) / sqrt(2);
end

function syms = Map_QAM16(bits)
    h = modem.qammod('M', 16, 'SymbolOrder', 'gray', 'InputType', 'bit');
    syms = modulate(h, reshape(bits, 4, length(bits) / 4));
    syms = conj(syms) / sqrt(10);
end

function syms = Map_QAM64(bits)
    h = modem.qammod('M', 64, 'SymbolOrder', 'gray', 'InputType', 'bit');
    syms = modulate(h, reshape(bits, 6, length(bits) / 6));
    syms = conj(syms) / sqrt(42);
end