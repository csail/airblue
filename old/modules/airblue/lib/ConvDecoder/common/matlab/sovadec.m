function out = sovadec( msg, llr, trl, win, new )
% SOVADEC is an implementation of the soft input soft output Viterbi 
%   algorithm. The algorithm can be called using
%       DEC = SOVADEC( MSG, LLR, TRELLIS, WIN )
%   where MSG is the soft input (codeword), LLR is a priori information
%   per bit about the bits (log likelihood ratios), TRELLIS is the 
%   trellis structure describing the convolutional encoder used to 
%   encode the original information message.
%   
%   The output of the function is the vector containing the soft 
%   estimates of the originally encoded information. The implementation
%   is able to perform decoding using any trellis structure compatibile
%   with the standard Matlab POLY2TRELLIS function.
%
%   WIN describes the size of the trellis buffer used to perform the
%   Viterbi algorithm. Thus, the decoder estimates the best path through
%   the trellis and searches back within this buffer at every decoding
%   time instant.
%   If WIN is omitted, the trellis of length N+1 (where N is the size
%   of the decoded message) is used.
%
%   For the estimation of the reliability information only the second
%   best path (competitor) is used, even if there are more than two
%   paths merging at a particular state.
%
%   The output of the decoding algorithm is of the following form
%       out = sign(inp) * log( P(inp=1|out) ) / log( P(inp=-1|out) )
%
% See also: POLY2TRELLIS, CONVENCO, VITDEC

%% (c) 2003 Adrian Bohdanowicz
%% $Id: sovadec.m,v 1.16 2003/06/15 14:57:29 adrian Exp $

    enc = trellis2enc( trl );
    if( enc.k == 1 )
        if ( new == 1 )
             out = sovadec_1N_new( msg, llr, trl, win );     % use 1/N optimized code (2x faster)
        else
             out = sovadec_1N( msg, llr, trl, win );
        end
    else
        out = sovadec_KN( msg, llr, trl, win );     % uset K/N generic code
    end
return;
    

function enc = trellis2enc( trl ),
% put the trellis structure into a more user friendly manner

    enc.k = log2( trl.numInputSymbols );            % number of inputs
    enc.n = log2( trl.numOutputSymbols );           % numbor of outputs
    enc.r = enc.k / enc.n;                          % code rate
    
    enc.ksym = trl.numInputSymbols;                 % number of possible input combinations
    enc.nsym = trl.numOutputSymbols;                % number of possible output combinations
    enc.stat = trl.numStates;                       % number of encoder states

    % forward transitions:
    enc.next.states = trl.nextStates + 1;                       % NEXT states
    enc.next.output = trl.outputs;                              % NEXT outputs
    for i = 1:enc.ksym,                                         % NEXT (binary) outputs
        enc.next.binout( :,:,i ) = 2*de2bi( oct2dec( trl.outputs(:,i) ), enc.n )-1;
    end
    
    % store possible binary outputs and inputs:
    enc.inp = de2bi( oct2dec( [0:enc.ksym-1] ), enc.k, 'left-msb' );        % all possible binary inputs
    enc.out = de2bi( oct2dec( [0:enc.nsym-1] ), enc.n, 'left-msb' );        % all possible binary outputs
    
    enc.bininp = 2*enc.inp-1;
return;


function out = sovadec_1N( msg, llr, trl, win ),
% SOVADEC optimized for 1/N encoders (faster!)

    % error checking:
    if( ~istrellis( trl ) ), error( 'Incorrect input trellis!' ); end;
    if( nargin <= 2 ), error( 'Incorrect number of input args!' ); end;
    if( nargin == 3 ), win = length( llr )+1; end;
    
    % some parameters:
    INF = 9e9;                                      % infinity
    enc = trellis2enc( trl );                       % encoder parameters
    len = length( llr ) / enc.k;                    % number of decoding steps (total)      
    win = min( [ win, len ] );                      % trim the buffer if msg is short
    old = NaN;                                      % to remember the last survivor
    
    % allocate memory for the trellis:
    metr = zeros( enc.stat, win+1 ) -INF;           % path metric buffer
    metr( 1,1 ) = 0;                                % initial state => (0,0)
    surv = zeros( enc.stat, win+1 );                % survivor state buffer
    inpt = zeros( enc.stat, win+1 );                % survivor input buffer (dec. output)
    diff = zeros( enc.stat, win+1 );                % path metric difference
    comp = zeros( enc.stat, win+1 );                % competitor state buffer
    inpc = zeros( enc.stat, win+1 );                % competitor input buffer

    out  = zeros( size(llr) ) + NaN;                % hard output (bits)
    sft  = zeros( size(llr) ) + INF;                % soft output (sign with reliability)


    % decode all the bits:
    for i = 1:len,
 
        % indices + precalcuations:
        Cur = mod( i-1, win+1 ) +1;                 % curr trellis (cycl. buf) position
        Nxt = mod( i,   win+1 ) +1;                 % next trellis (cycl. buf) position
        buf = msg( i*enc.n:-1:(i-1)*enc.n+1 );      % msg portion to be processed (reversed)
        llb = llr( (i-1)+1:i );                     % SOVA: llr portion to be processed
        metr( :,Nxt ) = -INF -INF;                  % (2*) helps in initial stages (!!!)

        
        %% forward recursion:
        for s = 1:enc.stat,
            for j = 1:enc.ksym,
                nxt = enc.next.states( s,  j );     % state after transition
                bin = enc.next.binout( s,:,j );     % transition output (encoder)
                mtr = bin*buf' + metr( s,Cur );     % transition metric
                mtr = mtr ...
                    + enc.bininp( j )*(llb*enc.r)'; % SOVA (Useful if there is a priori)
  
                if( metr( nxt,Nxt ) < mtr ),        % check whether this is better state than the best seen so far
                    diff( nxt,Nxt ) = mtr - metr( nxt,Nxt );    % SOVA
                    comp( nxt,Nxt ) = surv( nxt,Nxt );          % SOVA
                    inpc( nxt,Nxt ) = inpt( nxt,Nxt );          % SOVA
                    
                    metr( nxt,Nxt ) = mtr;          % store the metric
                    surv( nxt,Nxt ) = s;            % store the survival state
                    inpt( nxt,Nxt ) = j-1;          % store the survival input
                else
                    dif = metr( nxt,Nxt ) - mtr;    % check whether this is second best
                    if( dif <= diff( nxt,Nxt ) )
                        diff( nxt,Nxt ) = dif;                  % SOVA
                        comp( nxt,Nxt ) = s;                    % SOVA
                        inpc( nxt,Nxt ) = j-1;                  % SOVA
                    end
                end
            end
        end

        
        %% trace backwards:
        if( i < win ), continue; end;               % proceed if the buffer has been filled;
        [ mtr, sur ] = max( metr( :,Nxt ) );        % find the intitial state (max metric and its index)
        b = i;                                      % temporary bit index
        clc = mod( Nxt-[1:win], win+1 ) +1;         % indices in a 'cyclic buffer' operation
        
        for j = 1:win,                              % for all the bits in the buffer
            inp = inpt( sur, clc(j) );              % current bit-decoder output (encoder input)
            out( b ) = inp;                         % store the hard output

            tmp = clc( j );
            cmp = comp( sur, tmp );              % SOVA: competitor state (previous)
            inc = inpc( sur, tmp );              % SOVA: competitor bit output
            dif = diff( sur, tmp );              % SOVA: corresp. path metric difference
            srv = surv( sur, tmp );              % SOVA: temporary survivor path state
           
            for k = j+1:win+1,                      % check all buffer bits srv and cmp paths
                if( inp ~= inc ),
                    tmp = dif;
                    idx = b - ( (k-1)-j );          % calculate index: [enc.k*(b-(k-1)+j-1)+1:enc.k*(b-(k-1)+j)]
                    sft( idx ) = min( sft(idx), tmp );  % update LLRs for bits that are different
                end

                if( srv == cmp ), break; end;       % stop if surv and comp merge (no need to continue)              
                if( k == win+1 ), break; end;       % stop if the end (otherwise: error)
                tmp = clc( k );
                inp = inpt( srv, tmp );          % previous surv bit
                inc = inpt( cmp, tmp );          % previous comp bit
                srv = surv( srv, tmp );          % previous surv state
                cmp = surv( cmp, tmp );          % previous comp state
            end
            sur = surv( sur, clc(j) );              % state for the previous surv bit
            b = b - 1;                              % update bit index
        end
   end

   % provide soft output with +/- sign:
    out = (2*out-1) .* sft;
return;

function out = sovadec_1N_new( msg, llr, trl, win ),
% SOVADEC optimized for 1/N encoders (faster!)

    % error checking:
    if( ~istrellis( trl ) ), error( 'Incorrect input trellis!' ); end;
    if( nargin <= 2 ), error( 'Incorrect number of input args!' ); end;
    if( nargin == 3 ), win = length( llr )+1; end;
    
    % some parameters:
    INF = 9e9;                                      % infinity
    enc = trellis2enc( trl );                       % encoder parameters
    len = length( llr ) / enc.k;                    % number of decoding steps (total)      
    win = min( [ win, len ] );                      % trim the buffer if msg is short
    old = NaN;                                      % to remember the last survivor
    
    % allocate memory for the trellis:
    metr = zeros( enc.stat, win+1 ) -INF;           % path metric buffer
    metr( 1,1 ) = 0;                                % initial state => (0,0)
    surv = zeros( enc.stat, win+1 );                % survivor state buffer
    inpt = zeros( enc.stat, win+1 );                % survivor input buffer (dec. output)
    diff = zeros( enc.stat, win+1 );                % path metric difference
    comp = zeros( enc.stat, win+1 );                % competitor state buffer
    inpc = zeros( enc.stat, win+1 );                % competitor input buffer

    out  = zeros( size(llr) ) + NaN;                % hard output (bits)
    sft  = zeros( size(llr) ) + INF;                % soft output (sign with reliability)


    % decode all the bits:
    for i = 1:len,
 
        % indices + precalcuations:
        Cur = mod( i-1, win+1 ) +1;                 % curr trellis (cycl. buf) position
        Nxt = mod( i,   win+1 ) +1;                 % next trellis (cycl. buf) position
        buf = msg( i*enc.n:-1:(i-1)*enc.n+1 );      % msg portion to be processed (reversed)
        llb = llr( (i-1)+1:i );                     % SOVA: llr portion to be processed
        metr( :,Nxt ) = -INF -INF;                  % (2*) helps in initial stages (!!!)

        
        %% forward recursion:
        for s = 1:enc.stat,
            for j = 1:enc.ksym,
                nxt = enc.next.states( s,  j );     % state after transition
                bin = enc.next.binout( s,:,j );     % transition output (encoder)
                mtr = bin*buf' + metr( s,Cur );     % transition metric
                mtr = mtr ...
                    + enc.bininp( j )*(llb*enc.r)'; % SOVA (Useful if there is a priori)
  
                if( metr( nxt,Nxt ) < mtr ),        % check whether this is better state than the best seen so far
                    diff( nxt,Nxt ) = mtr - metr( nxt,Nxt );    % SOVA
                    comp( nxt,Nxt ) = surv( nxt,Nxt );          % SOVA
                    inpc( nxt,Nxt ) = inpt( nxt,Nxt );          % SOVA
                    
                    metr( nxt,Nxt ) = mtr;          % store the metric
                    surv( nxt,Nxt ) = s;            % store the survival state
                    inpt( nxt,Nxt ) = j-1;          % store the survival input
                else
                    dif = metr( nxt,Nxt ) - mtr;    % check whether this is second best
                    if( dif <= diff( nxt,Nxt ) )
                        diff( nxt,Nxt ) = dif;                  % SOVA
                        comp( nxt,Nxt ) = s;                    % SOVA
                        inpc( nxt,Nxt ) = j-1;                  % SOVA
                    end
                end
            end
        end

        %% trace backwards:
        if( i < win ), continue; end;               % proceed if the buffer has been filled;
        [ mtr, sur ] = max( metr( :,Nxt ) );        % find the intitial state (max metric and its index)
        b = i;                                      % temporary bit index
        clc = mod( Nxt-[1:win], win+1 ) +1;         % indices in a 'cyclic buffer' operation
        
        for j = 1:win,                              % for all the bits in the buffer
            inp = inpt( sur, clc(j) );              % current bit-decoder output (encoder input)
            out( b ) = inp;                         % store the hard output

            if ( j == win/2 )
                 tmp = clc( j ); 
                 cmp = comp( sur, tmp );              % SOVA: competitor state (previous)
                 inc = inpc( sur, tmp );              % SOVA: competitor bit output
                 dif = diff( sur, tmp );              % SOVA: corresp. path metric difference
                 srv = surv( sur, tmp );              % SOVA: temporary survivor path state
           
                 for k = j+1:win+1,                      % check all buffer bits srv and cmp paths
                     if( inp ~= inc ),
                         tmp = dif;
                         idx = b - ( (k-1)-j );          % calculate index: [enc.k*(b-(k-1)+j-1)+1:enc.k*(b-(k-1)+j)]
                         sft( idx ) = min( sft(idx), tmp );  % update LLRs for bits that are different
                     end

                     if( srv == cmp ), break; end;       % stop if surv and comp merge (no need to continue)              
                     if( k == win+1 ), break; end;       % stop if the end (otherwise: error)
                     tmp = clc( k );
                     inp = inpt( srv, tmp );          % previous surv bit
                     inc = inpt( cmp, tmp );          % previous comp bit
                     srv = surv( srv, tmp );          % previous surv state
                     cmp = surv( cmp, tmp );          % previous comp state
                 end
            end
            sur = surv( sur, clc(j) );              % state for the previous surv bit
            b = b - 1;                              % update bit index
        end
    end
%    
%         %% trace backwards:
% %        if( i < win ), continue; end;               % proceed if the buffer has been filled;
%         [ mtr, sur ] = max( metr( :,Nxt ) );        % find the intitial state (max metric and its index)
%         b = i;                                      % temporary bit index
%         clc = mod( Nxt-[1:win], win+1 ) +1;         % indices in a 'cyclic buffer' operation
% 
%         tmp = clc( 1 );
%         cmp = comp( sur, tmp );              % SOVA: competitor state (previous)
%         inc = inpc( sur, tmp );              % SOVA: competitor bit output
%         dif = diff( sur, tmp );              % SOVA: corresp. path metric difference
%         srv = surv( sur, tmp );              % SOVA: temporary survivor path state        
%         
%         for j = 1:min(i,win),                              % for all the bits in the buffer
%             inp = inpt( sur, tmp );                 % current bit-decoder output (encoder input)
%             out( b ) = inp;                         % store the hard output
%            
%             if( inp ~= inc ),
%                sft( b ) = min( sft(b), dif );  % update LLRs for bits that are different
%             end
% 
%             tmp = clc( j );
%             inc = inpt( cmp, tmp );          % previous comp bit
%             cmp = surv( cmp, tmp );          % previous comp state
%             sur = surv( sur, tmp );          % state for the previous surv bit
%             b = b - 1;                       % update bit index
%         end
%    end

   % provide soft output with +/- sign:
    out = (2*out-1) .* sft;
return;

function out = sovadec_KN( msg, llr, trl, win )

    % error checking:
    if( ~istrellis( trl ) ), error( 'Incorrect input trellis!' ); end;
    if( nargin <= 2 ), error( 'Incorrect number of input args!' ); end;
    if( nargin == 3 ), win = length( llr )+1; end;
    
    
    % some parameters:
    INF = 9e9;                                      % infinity
    enc = trellis2enc( trl );                       % encoder parameters
    len = length( llr ) / enc.k;                    % number of decoding steps (total)      
    win = min( [ win, len ] );                      % trim the buffer if msg is short
    old = NaN;                                      % to remember the last survivor
    
    % allocate memory for the trellis:
    metr = zeros( enc.stat, win+1 ) -INF;           % path metric buffer
    metr( 1,1 ) = 0;                                % initial state => (0,0)
    surv = zeros( enc.stat, win+1 );                % survivor state buffer
    inpt = zeros( enc.stat, win+1 );                % survivor input buffer (dec. output)
    diff = zeros( enc.stat, win+1 );                % path metric difference
    comp = zeros( enc.stat, win+1 );                % competitor state buffer
    inpc = zeros( enc.stat, win+1 );                % competitor input buffer

    out  = zeros( size(llr) ) + NaN;                % hard output (bits)
    sft  = zeros( size(llr) ) + INF;                % soft output (sign with reliability)

    

    % decode all the bits:
    for i = 1:len,
 
        % indices + precalcuations:
        Cur = mod( i-1, win+1 ) +1;                 % curr trellis (cycl. buf) position
        Nxt = mod( i,   win+1 ) +1;                 % next trellis (cycl. buf) position
        buf = msg( i*enc.n:-1:(i-1)*enc.n+1 );      % msg portion to be processed (reversed)
        llb = llr( (i-1)*enc.k+1:i*enc.k );         % SOVA: llr portion to be processed
        metr( :,Nxt ) = -INF -INF;                  % (2*) helps in initial stages (!!!)

        
        %% forward recursion:
        for s = 1:enc.stat,
            for j = 1:enc.ksym,
                nxt = enc.next.states( s,  j );     % state after transition
                bin = enc.next.binout( s,:,j );     % transition output (encoder)
                mtr = bin*buf' + metr( s,Cur );     % transition metric
                mtr = mtr ...
                    + enc.bininp(j,:)*(llb*enc.r)'; % SOVA
  
                if( metr( nxt,Nxt ) < mtr ),
                    diff( nxt,Nxt ) = mtr - metr( nxt,Nxt );    % SOVA
                    comp( nxt,Nxt ) = surv( nxt,Nxt );          % SOVA
                    inpc( nxt,Nxt ) = inpt( nxt,Nxt );          % SOVA
                    
                    metr( nxt,Nxt ) = mtr;          % store the metric
                    surv( nxt,Nxt ) = s;            % store the survival state
                    inpt( nxt,Nxt ) = j-1;          % store the survival input
                else
                    dif = metr( nxt,Nxt ) - mtr;
                    if( dif <= diff( nxt,Nxt ) )
                        diff( nxt,Nxt ) = dif;                  % SOVA
                        comp( nxt,Nxt ) = s;                    % SOVA
                        inpc( nxt,Nxt ) = j-1;                  % SOVA
                    end
                end
            end
        end

        
        %% trace backwards:
        if( i < win ), continue; end;               % proceed if the buffer has been filled;
        [ mtr, sur ] = max( metr( :,Nxt ) );        % find the intitial state (max metric)
        b = i;                                      % temporary bit index
        clc = mod( Nxt-[1:win], win+1 ) +1;         % indices in a 'cyclic buffer' operation
        
        for j = 1:win,                              % for all the bits in the buffer
            inp = inpt( sur, clc(j) );              % current bit-decoder output (encoder input)
            t = [ enc.k*(b-1)+1:enc.k*b ];          % compute the index 
            out( t ) = enc.inp( inp+1,: );          % store the hard output

            cmp = comp( sur, clc(j) );              % SOVA: competitor state (previous)
            inc = inpc( sur, clc(j) );              % SOVA: competitor bit output
            dif = diff( sur, clc(j) );              % SOVA: corresp. path metric difference
            srv = surv( sur, clc(j) );              % SOVA: temporary survivor path state
           
            for k = j+1:win+1,                      % check all buffer bits srv and cmp paths
                inp = enc.inp( inp+1, : );          % convert to binary form
                inc = enc.inp( inc+1, : );          % convert to binary form
                tmp = ( inp == inc )*INF + dif;     % for each different bit store the new dif
                idx = t - enc.k*( (k-1)-j );        % calculate index: [enc.k*(b-(k-1)+j-1)+1:enc.k*(b-(k-1)+j)]
                sft( idx ) = min( sft(idx), tmp );  % update LLRs for bits that are different

                if( srv == cmp ), break; end;       % stop if surv and comp merge (no need to continue)              
                if( k == win+1 ), break; end;       % stop if the end (otherwise: error)
                inp = inpt( srv, clc(k) );          % previous surv bit
                srv = surv( srv, clc(k) );          % previous surv state
                inc = inpt( cmp, clc(k) );          % previous comp bit
                cmp = surv( cmp, clc(k) );          % previous comp state
            end
            sur = surv( sur, clc(j) );              % state for the previous surv bit
            b = b - 1;                              % update bit index
        end
   end

   % provide soft output with +/- sign:
    out = (2*out-1) .* sft;
return;    


