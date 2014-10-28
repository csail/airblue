function bits = Demapper(syms, modulation, snr)
    sigma2 = 10^(-snr/10);
    switch modulation
        case 'BPSK'
            bits = Demap_BPSK(syms);% * 2;
        case 'QPSK'
            bits = Demap_QPSK(syms);% * sqrt(2);
        case 'QAM16'
            bits = Demap_QAM16(syms);% / sqrt(2);
%             bits = Demap_QAM16_new(syms * sqrt(10), sigma2) / sqrt(20);
%             return
        case 'QAM64'
            bits = Demap_QAM64(syms);% / (sqrt(6));
    end
    bits = bits * -1;
end

function bits = Demap_BPSK(syms)
    bits = real(syms);
end

function bits = Demap_QPSK(syms)
    t = [real(syms); imag(syms)];
    bits = reshape(t, 1, length(t) * 2);
end

function bits = Demap_QAM16(syms)
    t = [real(syms); 
         -abs(real(syms)) + 2/sqrt(10)
         imag(syms)
         -abs(imag(syms)) + 2/sqrt(10)
         ];
   bits = reshape(t, 1, length(t) * 4);
end

function bits = Demap_QAM16_new(syms, sigma2)
    h = modem.qamdemod('M', 16, 'SymbolOrder', 'gray', 'OutputType', 'bit', 'DecisionType', 'approximate llr', 'NoiseVariance', sigma2);
    bits = demodulate(h, reshape(conj(syms), 4, length(syms) / 4));
    bits = reshape(bits, 1, length(syms) * 4);
    bits = sqrt(abs(bits)) .* sign(bits);
end

function bits = Demap_QAM64(syms)
    t = [real(syms);
         -abs(real(syms)) + 4/sqrt(42);
         -abs(abs(real(syms)) - 4/sqrt(42)) + 2/sqrt(42);
         imag(syms);
         -abs(imag(syms)) + 4/sqrt(42);
         -abs(abs(imag(syms)) - 4/sqrt(42)) + 2/sqrt(42)
         ];
    bits = reshape(t, 1, length(t) * 6);         
end