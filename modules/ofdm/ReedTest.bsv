import Vector::*;

typedef Bit#(8)         Byte;
typedef Vector#(n,Byte) Syndrome#(numeric type n);

function Bool isNoError(Byte valid_t, Tuple2#(Integer, Byte) x);
   return (valid_t <= (fromInteger(tpl_1(x)) >> 1)) || (tpl_2(x) == 0);
endfunction
   
(* noinline *)
function Bool noError(Byte valid_t, Syndrome#(32) syndrome);
   Vector#(32,Bool) no_errors = map(isNoError(valid_t), zip(genVector,syndrome)); 
   return fold(\&& , no_errors);
endfunction 

