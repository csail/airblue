m = 8; % Number of bits per symbol
data_array = dlmread('./../../build/output/input.dat');
out_data_array = dlmread('./../../build/output/output.dat');
temp = size(data_array);
block_num = temp(1)/2^m;
dec_same = zeros(block_num,1);
prev_len = 0;
prev_k = 0;
for index = 1:block_num
    n = data_array(1 + prev_len,1);
    t = data_array(1 + prev_len,2);
    k = n - 2*t; 
    new_len = n + 1;
    if t == 0
       check = 1;
    else
        msg = data_array(2 + prev_len: new_len + prev_len);
        msgw = gf(msg,m); 
        [dc,nerrs,corrcode] = rsdec(msgw,n,k); % Decode the message.
        bsim_output = gf(out_data_array(2+prev_k:k+1+prev_k),m);
        check = isequal(dc,bsim_output);
        if check == 0
            display ('Mismatch found at index');
            index
        end
    end
    dec_same(index,1) = check;
    prev_len = prev_len + n + 1;
    prev_k = prev_k + k + 1;
end
display('Block comparision between matlab coding and bsim output completed');
display(sprintf('Number of blocks processed = %d',block_num));
num_mismatch = block_num - dot(dec_same,dec_same);
display(sprintf('Number of mismatches = %d',num_mismatch));

