%% Define Feedforward Convolutional Code
SNR_dB = 7.5
LM = 1716         % Mesg Length excluding pre-determined bits for starting & ending trellis at state 0
TREL_TYPE = 'Feedforward'  % {'Feedback', 'Feedforward'}
MODULATION = 'QAM16'
RATE = 1/2
WIN = 128
%% Matlab Generator Polynomial convention
% Build a binary number representation by placing a 1 in each spot where a connection line from the shift register feeds into the adder,
% and a 0 elsewhere. The leftmost spot in the binary number represents the current input, while the rightmost spot represents the 
% oldest input that still remains in the shift register.

if strcmp(TREL_TYPE, 'Feedback')    
%     CL = 2		% Rate 1/2 Feedback encoder with 2 states
%     GenPoly0_1by2 = 3 % in octal
%     GenPoly1_1by2 = 2
%     FeedBackCoef = [1,1];  % For computing i/p bits needed to terminate trellis at state =0.
%     TREL = poly2trellis(CL, [GenPoly0_1by2, GenPoly1_1by2], GenPoly0_1by2)

%% Rate 1/2 Feedback encoder with 8-states used in 3GPP cellular 3G/4G standard
    CL = 4  
    GenPoly0_1by2 = 13 % in octal
    GenPoly1_1by2 = 15
    FeedBackCoef = [1,0,1,1];% For computing i/p bits needed to terminate trellis at state =0.
    TREL = poly2trellis(CL, [GenPoly0_1by2, GenPoly1_1by2], GenPoly0_1by2)    
    
else
    %% Rate 1/3 Feedforward encoder with 4 states
%     CL = 3; % constraint length
%     GenPoly0_third = 4; % in octal
%     GenPoly1_third = 5;
%     GenPoly2_third = 7;
%     TREL = poly2trellis( CL, [GenPoly0_third, GenPoly1_third, GenPoly2_third])    

%     CL = 4 % constraint length
%     GenPoly0_1by4 = 13 % in octal
%     GenPoly1_1by4 = 15
%     GenPoly2_1by4 = 15
%     GenPoly3_1by4 = 17
%     TREL = poly2trellis( CL, [GenPoly0_1by4, GenPoly1_1by4, GenPoly2_1by4, GenPoly3_1by4])

    CL = 7
    TREL = poly2trellis( CL, [133, 171])

end
LM = LM + 2*(CL-1) % space for start & tail bits

%% Verify trellis-structure is OK
[isok, status] = istrellis(TREL) 

% Always use same random sequence
% randn('state', 0)

%% The encoder is assumed to have both started and ended at the all-zeros state
%% Ensure msg is s.t. trellis starts at "0" state and ends at "0" state. 
%%  Generate Random binary stream & encode 
if strcmp(TREL_TYPE, 'Feedback')
    msg1(1 : CL-1) = zeros(1, CL-1); % 1st (CL-1) bits must be 0
    msg1(CL : LM -CL+1) = randint(LM -2*CL +2, 1, 2)' ; % Random data
% 	msg1(CL : LM -CL+1) = [0 1];

    % Encode first part of msg, recording final state for later use.
    [cenc_o1, final_state1] = convenc(msg1, TREL);

    % Rest of msg depends on final_state1; it makes trellis terminate at final_state=0. 
    bvec_fs = bitget(final_state1, (CL-1) : -1 : 1); % All possible binary-vectors of length EncoderN
    for idx = 1 : (CL-1)
        msg2(idx) = rem( [0, bvec_fs]*FeedBackCoef', 2);
        bvec_fs = [0, bvec_fs(1: (end-1))];
    end
%     msg2(1 : CL -1) = bvec_fs; % Last (CL-1) bits depend on state at time=(LM-CL+1)
    [cenc_o2, final_state] = convenc(msg2, TREL, final_state1);
    
    msg = [msg1, msg2]; clear msg1 msg2
    [cenc_o] = [cenc_o1, cenc_o2]; clear cenc_o1 cenc_o2
    final_state    
else % Feedforward
    msg = zeros(1, LM);
    msg(1 : CL-1) = zeros(1,CL-1); % 1st (CL-1) bits must be 0
    msg(CL : LM -CL+1) = randint(LM -2*CL +2, 1, 2)' ; % Random data    
    msg(LM -CL + 2 : LM) = zeros(CL-1, 1); % Last (CL-1) bits must be 0
    if RATE == 1/2
        [cenc_o, final_state] = convenc(msg, TREL);
    elseif RATE == 3/4
        [cenc_o, final_state] = convenc(msg, TREL, [1 1 1 0 0 1]);
    else
        display('UNEXPECTED RATE')
        return
    end
end

if final_state ~= 0
    disp('trellis not terminated properly: check last (CL-1) bits of mesg')
    return
end

%%	Map to BPSK constellation: bit0 -> 1, bit1 -> -1
signal_power = 1;
interleaved = Interleaver(cenc_o, MODULATION);
chan_in = Mapper(interleaved, MODULATION);

total_errors = 0;
total_expected = 0;

errors = zeros(256,1);
total = zeros(256,1);

tic
for test = 1:50

%%	Generate and add Gaussian-noise mean=0, variance= noise_power
noise_power = signal_power / 10^(SNR_dB/10);
noise = randn(size(chan_in))*sqrt(noise_power);
% chan_o = chan_in + noise;

chan_o = chan_in;
chan_o = chan_o + wgn(1, length(chan_in), -SNR_dB, 'complex');
map_in = chan_o;
chan_o = Demapper(chan_o, MODULATION, SNR_dB);

% Estimate SNR
% k=2;
% l=4;
% v = (sum(abs(map_in).^k)/length(map_in))^l / ...
% (sum(abs(map_in).^l)/length(map_in))^k;
% 
% [C,I] = min(abs(table - v));
% snr = (I-1)/10
% sigma2 = 10^(-snr/10);


% Use exact SNR
% sigma2 = 10^(-SNR_dB/10);
% chan_o = chan_o / sigma2;
% 
% switch MODULATION
%         case 'BPSK'
%             chan_o = chan_o * 2;
%         case 'QPSK'
%             chan_o = chan_o / sqrt(2);
%         case 'QAM16'
%             chan_o = chan_o / sqrt(2);
%         case 'QAM64'
%             chan_o = chan_o / (sqrt(6));
% end

chan_o = Deinterleaver(chan_o, MODULATION);


if RATE == 3/4
    eras = zeros(1, length(chan_o) * 3/2);
    eras(1:6:end) = chan_o(1:4:end);
    eras(2:6:end) = chan_o(2:4:end);
    eras(3:6:end) = chan_o(3:4:end);
    eras(6:6:end) = chan_o(4:4:end);
    chan_o = eras;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % BCJR
% % Es = signal_power/log2(TREL.numOutputSymbols);
% % No = noise_power;
% % Lc = 4*Es/No;
% Lc = 2;
% 
% %	Soft-Decision decoding, map to decision values
% soft_in = chan_o;
% %decodeds = vitdec_htm(TREL, soft_in');
% 
% global LLR Alpha Beta
% [LLR, Alpha, Beta] = LogMAPdecode_htm(TREL, chan_o, Lc);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SOVA

pllr = zeros(1,length(msg)); % a priori llr = 0 

chan_o = chan_o * -1;

global LLR
LLR = sovadec(chan_o, pllr, TREL, WIN, 1);
LLR = LLR * -1;

% global LLR2
% LLR2 = sovadec(chan_o, pllr, TREL, WIN, 0);
% LLR2 = LLR2 * -1;
% LLR2 = LLR2(WIN:length(LLR2)-WIN);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% LLR = LLR * 4;
LLR = LLR(WIN:length(LLR)-WIN);
%disp( [msg(WIN:length(LLR)+WIN-1)', (LLR<0)', LLR', LLR2']);
sigma2 = 10^(-SNR_dB/10);
LLR = LLR / sigma2;

switch MODULATION
        case 'BPSK'
            LLR = LLR * 2;
        case 'QPSK'
            LLR = LLR / sqrt(2);
        case 'QAM16'
            LLR = LLR / sqrt(2);
        case 'QAM64'
            LLR = LLR / (sqrt(6));
end

decd_msg = (1 - sign(LLR))/2;
err_vec = abs(decd_msg - msg(WIN:length(LLR)+WIN-1));

for i = 1:length(LLR)
    hint = min(255, max(-255, round(abs(LLR(i)))));
    total(hint + 1) = total(hint + 1) + 1;
    if (err_vec(i) ~= 0)
        errors(hint + 1) = errors(hint + 1) + 1;
    end
end

% sprintf('# of Bit-Errors = %d out of %d info-bits ', sum(abs(err_vec)), LM -CL -2)

total_expected = total_expected + sum(1 ./ (1 + exp(abs(LLR))));
total_errors = total_errors + sum(abs(err_vec));

end
toc
% 
total_errors
total_expected

ber = log(errors ./ total);
plot(ber(1:50), 'x');
hold()
plot(log(1 ./ (1 + exp(1:50))));
% 
% errors
% errors ./ total
