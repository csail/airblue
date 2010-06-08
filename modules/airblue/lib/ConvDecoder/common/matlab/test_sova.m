%trl = poly2trellis( 3, [7 5], 7 );
trl = poly2trellis( 7, [133 171] );
  win = 35;
  len = 70;
  inp = randint( 1, len );
  enc = convenc( inp, trl );

  msg = 2*enc - 1;
  %msg = msg + 0.1*randn( 1, length(msg) );

  llr = zeros( 1, len );
  out = sovadec( msg, llr, trl, win );
  hrd = vitdec( (msg>0), trl, win, 'trunc', 'hard' );

  inp
  soft = sign(out)/2 + 0.5 
  
  disp( [ inp(1:len)', out(1:len)', hrd(1:len)' ] );
