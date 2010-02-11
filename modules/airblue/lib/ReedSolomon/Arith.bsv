//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2007 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

//**********************************************************************
// Galois field arithmetic
//----------------------------------------------------------------------
// $Id: Arith.bsv
//
		 
import Types::*;


// -----------------------------------------------------------
// The primitive polynomial defines the Galois field in which 
// Reed-Solomon decoder operates, and all the following		  
// arithmetic operations are defined under.  Changing this 	  
// value cause the whole Reed-Solomon decoder to operate		  
// under the new primitive polynomial.
// primitive_polynomial[i] = Coefficient of x**i for i = 0:7

// -----------------------------------------------------------
Byte	primitive_polynomial = 8'b00011101;
Byte    n_param              = 8'd255;
Byte    t_param              = 8'd16;

// -----------------------------------------------------------
(* noinline *) 
function Byte gf_mult (Byte left, Byte right);

   Word result = 16'b0;

//    for (int i = 0; i < 8; i = i + 1)
//       for (int j = 0; j < 8; j = j + 1)
// 	 result [i + j] = result [i + j] ^ (left [j] & right [i]);

//    for (int i = 15; i > 7; i = i - 1)
//       if (result [i] == 1'b1)
// 	 result = result ^ ((zeroExtend (primitive_polynomial)) << (i - 8));
         
   result [0] = result [0] ^ (left [0] & right [0]);
   result [1] = result [1] ^ (left [1] & right [0]) ^ (left [0] & right [1]);
   result [2] = result [2] ^ (left [2] & right [0]) ^ (left [1] & right [1]) ^ (left [0] & right [2]);
   result [3] = result [3] ^ (left [3] & right [0]) ^ (left [2] & right [1]) ^ (left [1] & right [2]) ^ (left [0] & right [3]);
   result [4] = result [4] ^ (left [4] & right [0]) ^ (left [3] & right [1]) ^ (left [2] & right [2]) ^ (left [1] & right [3]) ^ (left [0] & right [4]);
   result [5] = result [5] ^ (left [5] & right [0]) ^ (left [4] & right [1]) ^ (left [3] & right [2]) ^ (left [2] & right [3]) ^ (left [1] & right [4]) ^ (left [0] & right [5]);
   result [6] = result [6] ^ (left [6] & right [0]) ^ (left [5] & right [1]) ^ (left [4] & right [2]) ^ (left [3] & right [3]) ^ (left [2] & right [4]) ^ (left [1] & right [5]) ^ (left [0] & right [6]);
   result [7] = result [7] ^ (left [7] & right [0]) ^ (left [6] & right [1]) ^ (left [5] & right [2]) ^ (left [4] & right [3]) ^ (left [3] & right [4]) ^ (left [2] & right [5]) ^ (left [1] & right [6]) ^ (left [0] & right [7]);
   result [8] = result [8] ^ (left [7] & right [1]) ^ (left [6] & right [2]) ^ (left [5] & right [3]) ^ (left [4] & right [4]) ^ (left [3] & right [5]) ^ (left [2] & right [6]) ^ (left [1] & right [7]);
   result [9] = result [9] ^ (left [7] & right [2]) ^ (left [6] & right [3]) ^ (left [5] & right [4]) ^ (left [4] & right [5]) ^ (left [3] & right [6]) ^ (left [2] & right [7]);
   result [10] = result [10] ^ (left [7] & right [3]) ^ (left [6] & right [4]) ^ (left [5] & right [5]) ^ (left [4] & right [6]) ^ (left [3] & right [7]);
   result [11] = result [11] ^ (left [7] & right [4]) ^ (left [6] & right [5]) ^ (left [5] & right [6]) ^ (left [4] & right [7]);
   result [12] = result [12] ^ (left [7] & right [5]) ^ (left [6] & right [6]) ^ (left [5] & right [7]);
   result [13] = result [13] ^ (left [7] & right [6]) ^ (left [6] & right [7]);
   result [14] = result [14] ^ (left [7] & right [7]);

   if (result [14] == 1'b1)
      result = result ^ ((zeroExtend (primitive_polynomial)) << (6));
   if (result [13] == 1'b1)
      result = result ^ ((zeroExtend (primitive_polynomial)) << (5));
   if (result [12] == 1'b1)
      result = result ^ ((zeroExtend (primitive_polynomial)) << (4));
   if (result [11] == 1'b1)
      result = result ^ ((zeroExtend (primitive_polynomial)) << (3));
   if (result [10] == 1'b1)
      result = result ^ ((zeroExtend (primitive_polynomial)) << (2));
   if (result [9] == 1'b1)
      result = result ^ ((zeroExtend (primitive_polynomial)) << (1));
   if (result [8] == 1'b1)
      result = result ^ ((zeroExtend (primitive_polynomial)) << (0));

   return (result [7:0]);

endfunction



// -----------------------------------------------------------
function Byte gf_add (Byte left, Byte right);
   return (left ^ right);
endfunction



// -----------------------------------------------------------
// function Byte const_alpha_n (int n);

//    //if (n == 0)
//    //   return 1;
//    Byte a_n = 2;
//    for (int i = 1; i < n; i = i + 1)
//       a_n = gf_mult (a_n, 2);
//    return a_n;

// endfunction

function Byte gf_inv (Byte a);

   case (a) matches
        0 : return         2;
        1 : return         1;
        2 : return       142;
        3 : return       244;
        4 : return        71;
        5 : return       167;
        6 : return       122;
        7 : return       186;
        8 : return       173;
        9 : return       157;
       10 : return       221;
       11 : return       152;
       12 : return        61;
       13 : return       170;
       14 : return        93;
       15 : return       150;
       16 : return       216;
       17 : return       114;
       18 : return       192;
       19 : return        88;
       20 : return       224;
       21 : return        62;
       22 : return        76;
       23 : return       102;
       24 : return       144;
       25 : return       222;
       26 : return        85;
       27 : return       128;
       28 : return       160;
       29 : return       131;
       30 : return        75;
       31 : return        42;
       32 : return       108;
       33 : return       237;
       34 : return        57;
       35 : return        81;
       36 : return        96;
       37 : return        86;
       38 : return        44;
       39 : return       138;
       40 : return       112;
       41 : return       208;
       42 : return        31;
       43 : return        74;
       44 : return        38;
       45 : return       139;
       46 : return        51;
       47 : return       110;
       48 : return        72;
       49 : return       137;
       50 : return       111;
       51 : return        46;
       52 : return       164;
       53 : return       195;
       54 : return        64;
       55 : return        94;
       56 : return        80;
       57 : return        34;
       58 : return       207;
       59 : return       169;
       60 : return       171;
       61 : return        12;
       62 : return        21;
       63 : return       225;
       64 : return        54;
       65 : return        95;
       66 : return       248;
       67 : return       213;
       68 : return       146;
       69 : return        78;
       70 : return       166;
       71 : return         4;
       72 : return        48;
       73 : return       136;
       74 : return        43;
       75 : return        30;
       76 : return        22;
       77 : return       103;
       78 : return        69;
       79 : return       147;
       80 : return        56;
       81 : return        35;
       82 : return       104;
       83 : return       140;
       84 : return       129;
       85 : return        26;
       86 : return        37;
       87 : return        97;
       88 : return        19;
       89 : return       193;
       90 : return       203;
       91 : return        99;
       92 : return       151;
       93 : return        14;
       94 : return        55;
       95 : return        65;
       96 : return        36;
       97 : return        87;
       98 : return       202;
       99 : return        91;
      100 : return       185;
      101 : return       196;
      102 : return        23;
      103 : return        77;
      104 : return        82;
      105 : return       141;
      106 : return       239;
      107 : return       179;
      108 : return        32;
      109 : return       236;
      110 : return        47;
      111 : return        50;
      112 : return        40;
      113 : return       209;
      114 : return        17;
      115 : return       217;
      116 : return       233;
      117 : return       251;
      118 : return       218;
      119 : return       121;
      120 : return       219;
      121 : return       119;
      122 : return         6;
      123 : return       187;
      124 : return       132;
      125 : return       205;
      126 : return       254;
      127 : return       252;
      128 : return        27;
      129 : return        84;
      130 : return       161;
      131 : return        29;
      132 : return       124;
      133 : return       204;
      134 : return       228;
      135 : return       176;
      136 : return        73;
      137 : return        49;
      138 : return        39;
      139 : return        45;
      140 : return        83;
      141 : return       105;
      142 : return         2;
      143 : return       245;
      144 : return        24;
      145 : return       223;
      146 : return        68;
      147 : return        79;
      148 : return       155;
      149 : return       188;
      150 : return        15;
      151 : return        92;
      152 : return        11;
      153 : return       220;
      154 : return       189;
      155 : return       148;
      156 : return       172;
      157 : return         9;
      158 : return       199;
      159 : return       162;
      160 : return        28;
      161 : return       130;
      162 : return       159;
      163 : return       198;
      164 : return        52;
      165 : return       194;
      166 : return        70;
      167 : return         5;
      168 : return       206;
      169 : return        59;
      170 : return        13;
      171 : return        60;
      172 : return       156;
      173 : return         8;
      174 : return       190;
      175 : return       183;
      176 : return       135;
      177 : return       229;
      178 : return       238;
      179 : return       107;
      180 : return       235;
      181 : return       242;
      182 : return       191;
      183 : return       175;
      184 : return       197;
      185 : return       100;
      186 : return         7;
      187 : return       123;
      188 : return       149;
      189 : return       154;
      190 : return       174;
      191 : return       182;
      192 : return        18;
      193 : return        89;
      194 : return       165;
      195 : return        53;
      196 : return       101;
      197 : return       184;
      198 : return       163;
      199 : return       158;
      200 : return       210;
      201 : return       247;
      202 : return        98;
      203 : return        90;
      204 : return       133;
      205 : return       125;
      206 : return       168;
      207 : return        58;
      208 : return        41;
      209 : return       113;
      210 : return       200;
      211 : return       246;
      212 : return       249;
      213 : return        67;
      214 : return       215;
      215 : return       214;
      216 : return        16;
      217 : return       115;
      218 : return       118;
      219 : return       120;
      220 : return       153;
      221 : return        10;
      222 : return        25;
      223 : return       145;
      224 : return        20;
      225 : return        63;
      226 : return       230;
      227 : return       240;
      228 : return       134;
      229 : return       177;
      230 : return       226;
      231 : return       241;
      232 : return       250;
      233 : return       116;
      234 : return       243;
      235 : return       180;
      236 : return       109;
      237 : return        33;
      238 : return       178;
      239 : return       106;
      240 : return       227;
      241 : return       231;
      242 : return       181;
      243 : return       234;
      244 : return         3;
      245 : return       143;
      246 : return       211;
      247 : return       201;
      248 : return        66;
      249 : return       212;
      250 : return       232;
      251 : return       117;
      252 : return       127;
      253 : return       255;
      254 : return       126;
      255 : return       253;
   endcase
         
endfunction

function Byte alpha_chien (Byte a);

   case (a) matches
        1 : return         2;
        2 : return         4;
        3 : return         8;
        4 : return        16;
        5 : return        32;
        6 : return        64;
        7 : return       128;
        8 : return        29;
        9 : return        58;
       10 : return       116;
       11 : return       232;
       12 : return       205;
       13 : return       135;
       14 : return        19;
       15 : return        38;
       16 : return        76;
       17 : return       152;
       18 : return        45;
       19 : return        90;
       20 : return       180;
       21 : return       117;
       22 : return       234;
       23 : return       201;
       24 : return       143;
       25 : return         3;
       26 : return         6;
       27 : return        12;
       28 : return        24;
       29 : return        48;
       30 : return        96;
       31 : return       192;
       32 : return       157;
   endcase
endfunction

function Byte alpha_inv_chien (Byte a);
   case (a) matches
        0 : return         1;
        1 : return       142;
        2 : return        71;
        3 : return       173;
        4 : return       216;
        5 : return       108;
        6 : return        54;
        7 : return        27;
        8 : return       131;
        9 : return       207;
       10 : return       233;
       11 : return       250;
       12 : return       125;
       13 : return       176;
       14 : return        88;
       15 : return        44;
       16 : return        22;
       17 : return        11;
       18 : return       139;
       19 : return       203;
       20 : return       235;
       21 : return       251;
       22 : return       243;
       23 : return       247;
       24 : return       245;
       25 : return       244;
       26 : return       122;
       27 : return        61;
       28 : return       144;
       29 : return        72;
       30 : return        36;
       31 : return        18;
       32 : return         9;
       33 : return       138;
       34 : return        69;
       35 : return       172;
       36 : return        86;
       37 : return        43;
       38 : return       155;
       39 : return       195;
       40 : return       239;
       41 : return       249;
       42 : return       242;
       43 : return       121;
       44 : return       178;
       45 : return        89;
       46 : return       162;
       47 : return        81;
       48 : return       166;
       49 : return        83;
       50 : return       167;
       51 : return       221;
       52 : return       224;
       53 : return       112;
       54 : return        56;
       55 : return        28;
       56 : return        14;
       57 : return         7;
       58 : return       141;
       59 : return       200;
       60 : return       100;
       61 : return        50;
       62 : return        25;
       63 : return       130;
       64 : return        65;
       65 : return       174;
       66 : return        87;
       67 : return       165;
       68 : return       220;
       69 : return       110;
       70 : return        55;
       71 : return       149;
       72 : return       196;
       73 : return        98;
       74 : return        49;
       75 : return       150;
       76 : return        75;
       77 : return       171;
       78 : return       219;
       79 : return       227;
       80 : return       255;
       81 : return       241;
       82 : return       246;
       83 : return       123;
       84 : return       179;
       85 : return       215;
       86 : return       229;
       87 : return       252;
       88 : return       126;
       89 : return        63;
       90 : return       145;
       91 : return       198;
       92 : return        99;
       93 : return       191;
       94 : return       209;
       95 : return       230;
       96 : return       115;
       97 : return       183;
       98 : return       213;
       99 : return       228;
      100 : return       114;
      101 : return        57;
      102 : return       146;
      103 : return        73;
      104 : return       170;
      105 : return        85;
      106 : return       164;
      107 : return        82;
      108 : return        41;
      109 : return       154;
      110 : return        77;
      111 : return       168;
      112 : return        84;
      113 : return        42;
      114 : return        21;
      115 : return       132;
      116 : return        66;
      117 : return        33;
      118 : return       158;
      119 : return        79;
      120 : return       169;
      121 : return       218;
      122 : return       109;
      123 : return       184;
      124 : return        92;
      125 : return        46;
      126 : return        23;
      127 : return       133;
      128 : return       204;
      129 : return       102;
      130 : return        51;
      131 : return       151;
      132 : return       197;
      133 : return       236;
      134 : return       118;
      135 : return        59;
      136 : return       147;
      137 : return       199;
      138 : return       237;
      139 : return       248;
      140 : return       124;
      141 : return        62;
      142 : return        31;
      143 : return       129;
      144 : return       206;
      145 : return       103;
      146 : return       189;
      147 : return       208;
      148 : return       104;
      149 : return        52;
      150 : return        26;
      151 : return        13;
      152 : return       136;
      153 : return        68;
      154 : return        34;
      155 : return        17;
      156 : return       134;
      157 : return        67;
      158 : return       175;
      159 : return       217;
      160 : return       226;
      161 : return       113;
      162 : return       182;
      163 : return        91;
      164 : return       163;
      165 : return       223;
      166 : return       225;
      167 : return       254;
      168 : return       127;
      169 : return       177;
      170 : return       214;
      171 : return       107;
      172 : return       187;
      173 : return       211;
      174 : return       231;
      175 : return       253;
      176 : return       240;
      177 : return       120;
      178 : return        60;
      179 : return        30;
      180 : return        15;
      181 : return       137;
      182 : return       202;
      183 : return       101;
      184 : return       188;
      185 : return        94;
      186 : return        47;
      187 : return       153;
      188 : return       194;
      189 : return        97;
      190 : return       190;
      191 : return        95;
      192 : return       161;
      193 : return       222;
      194 : return       111;
      195 : return       185;
      196 : return       210;
      197 : return       105;
      198 : return       186;
      199 : return        93;
      200 : return       160;
      201 : return        80;
      202 : return        40;
      203 : return        20;
      204 : return        10;
      205 : return         5;
      206 : return       140;
      207 : return        70;
      208 : return        35;
      209 : return       159;
      210 : return       193;
      211 : return       238;
      212 : return       119;
      213 : return       181;
      214 : return       212;
      215 : return       106;
      216 : return        53;
      217 : return       148;
      218 : return        74;
      219 : return        37;
      220 : return       156;
      221 : return        78;
      222 : return        39;
      223 : return       157;
      224 : return       192;
      225 : return        96;
      226 : return        48;
      227 : return        24;
      228 : return        12;
      229 : return         6;
      230 : return         3;
      231 : return       143;
      232 : return       201;
      233 : return       234;
      234 : return       117;
      235 : return       180;
      236 : return        90;
      237 : return        45;
      238 : return       152;
      239 : return        76;
      240 : return        38;
      241 : return        19;
      242 : return       135;
      243 : return       205;
      244 : return       232;
      245 : return       116;
      246 : return        58;
      247 : return        29;
      248 : return       128;
      249 : return        64;
      250 : return        32;
      251 : return        16;
      252 : return         8;
      253 : return         4;
      254 : return         2;
   endcase
endfunction

