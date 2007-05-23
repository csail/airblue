m = 8; % Number of bits per symbol
n = 2^m-1; k = 223; % Codeword length and message length
t = (n-k)/2; % Error-correction capability of the code
nw = 1; % Number of messages to process
%msg = randint(nw,k,2^m);
msg = [130, 166, 57, 161, 18, 59, 83, 80, 178, 58, 160, 63, 165, 19, 226, 211, 41, 126, 170, 250, 230, 189, 249, 211, 222, 235, 212, 190, 9, 160, 190, 223, 147, 253, 77, 193, 135, 25, 175, 115, 147, 140, 91, 209, 232, 99, 41, 45, 151, 235, 1, 18, 221, 13, 254, 31, 226, 52, 254, 40, 13, 192, 146, 209, 117, 52, 17, 19, 132, 34, 23, 193, 163, 246, 167, 186, 203, 61, 44, 132, 13, 242, 19, 189, 41, 202, 31, 186, 38, 62, 149, 59, 75, 94, 191, 97, 174, 238, 251, 193, 126, 32, 26, 231, 43, 106, 141, 70, 47, 57, 113, 78, 200, 71, 157, 110, 163, 224, 37, 234, 242, 55, 123, 232, 174, 207, 101, 235, 112, 218, 167, 150, 243, 175, 89, 227, 58, 84, 211, 224, 112, 42, 175, 90, 163, 188, 72, 183, 237, 237, 111, 10, 135, 170, 130, 193, 95, 137, 67, 216, 230, 247, 60, 16, 116, 5, 16, 88, 227, 169, 49, 21, 134, 242, 17, 234, 205, 89, 72, 227, 102, 196, 134, 196, 74, 248, 125, 133, 162, 75, 156, 213, 130, 55, 254, 27, 33, 102, 39, 205, 34, 61, 4, 154, 36, 182, 162, 233, 242, 130, 93, 160, 121, 141, 70, 195, 85, 50, 232, 203, 199, 100, 214];
msgw = gf(msg,m); % Random k-symbol messages
c = rsenc(msgw,n,k); % Encode the data.
% fid = fopen('test_enc_input.dat','w+');
% normal_array = zeros(1,n);
% for i = 1:n
%     normal_array(i) = c(i);
% end
% fprintf(fid,'%d\n',normal_array);
noise = (1+randint(nw,n,2^m-1)).*randerr(nw,n,t); % t errors/row
cnoisy = c + noise; % Add noise to the code.
[dc,nerrs,corrcode] = rsdec(cnoisy,n,k); % Decode the noisy code.
% Check that the decoding worked correctly.
isequal(dc,msgw) & isequal(corrcode,c)
nerrs % Find out how many errors rsdec corrected.
