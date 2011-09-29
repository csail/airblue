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

import GetPut::*;

`include "awb/provides/airblue_parameters.bsh"
`include "awb/provides/fpga_components.bsh"
`include "awb/provides/librl_bsv_base.bsh"
`include "awb/provides/librl_bsv_storage.bsh"

module mkConvDecoderInstance#(function Bool decodeBoundary(ctrl_t ctrl),
                              Integer ctrl_q_sz)
   (IViterbi viterbi, Viterbi#(ctrl_t,n2,n) ifc)
   provisos(Log#(n2,ln2),
            Log#(n,ln),
            Bits#(ctrl_t, ctrl_sz));

   // constants
   // n must be multiple of fwd_steps * conv_in_sz
   Bit#(ln)  check_n   = fromInteger(valueOf(n)-(fwd_steps * conv_in_sz));
   // n must be multiple of fwd_steps * conv_out_sz
   Bit#(ln2) check_n2  = fromInteger(valueOf(n2)-(fwd_steps * conv_out_sz));

   FIFO#(DecoderMesg#(ctrl_t,n2,ViterbiMetric)) in_q <- mkLFIFO;
   Reg#(Bit#(ln2)) in_data_count <- mkReg(0);
   Reg#(Vector#(n,ViterbiOutput)) out_data <- mkReg(newVector);
   Reg#(Bit#(ln)) out_data_count <- mkReg(0);
   FIFO#(DecoderMesg#(ctrl_t,n,ViterbiOutput)) out_q <- mkSizedFIFO(2);
   FIFO#(ctrl_t) ctrl_q <- mkSizedBRAMFIFO(ctrl_q_sz);


   rule pushData;
      DecoderMesg#(ctrl_t,n2,ViterbiMetric) in_mesg = in_q.first;
      ctrl_t in_ctrl = in_mesg.control;
      Vector#(n2,ViterbiMetric) in_data = in_mesg.data;
      Vector#(1,Vector#(ConvOutSz, VMetric)) v_data = newVector;
      for (Integer i = 0; i < fwd_steps; i = i + 1)
         begin
            for (Integer j = 0; j < conv_out_sz; j = j + 1)
               begin
                  let offset = i * conv_out_sz + j;
                  v_data[i][j] = in_data[in_data_count + fromInteger(offset)];
               end
         end


      // when does it end?
      if (in_data_count == check_n2) // means we have finished processing input
         begin
            if(`DEBUG_CONV_DECODER == 1)
              begin
                $display("ConvDecoder top level deqs value");
              end 

            in_q.deq;
            in_data_count <= 0;
            ctrl_q.enq(in_ctrl);
            if (decodeBoundary(in_ctrl))
              begin
                if(`DEBUG_CONV_DECODER == 1)
                  begin
                    $display("ConvDecoder Pushing decode boundary");
                  end

                viterbi.putData(tuple2(True,v_data)); 
              end
            else
               begin
                viterbi.putData(tuple2(False,v_data)); 
              end
         end
      else
        begin
          in_data_count <= in_data_count + fromInteger(fwd_steps * conv_out_sz);
          viterbi.putData(tuple2(False,v_data)); 
        end


      if(`DEBUG_CONV_DECODER == 1)
        begin
          $display("pushDataToViterbi");
        end
   endrule
   

   rule pullData;
      VOutType v_data <- viterbi.getResult();
      Vector#(n,ViterbiOutput) new_out_data = out_data;
      for (Integer i = 0 ; i < fwd_steps; i = i + 1)
         begin
            for (Integer j = 0; j < conv_in_sz; j = j + 1)
               begin
                  let offset = i * conv_in_sz + j;
                  let idx = out_data_count + fromInteger(offset);
                  new_out_data[idx] = select(v_data, i, j);
               end
         end
      out_data <= new_out_data;
      if (out_data_count == check_n) // means we have finished processing output
         begin
           if(`DEBUG_CONV_DECODER == 1)
             begin      
               $display("ConvDecoder out data: %h", new_out_data);
             end
           out_q.enq(Mesg{control:ctrl_q.first, data:new_out_data});
           out_data_count <= 0;
           ctrl_q.deq;
         end
      else
         begin
            out_data_count <= out_data_count + fromInteger(fwd_steps * conv_in_sz);
         end

      if(`DEBUG_CONV_DECODER == 1)
        begin      
          $display("pullDataFromViterbi");
        end
   endrule

   interface in  = toPut(in_q);
   interface out = toGet(out_q); 
  
endmodule
