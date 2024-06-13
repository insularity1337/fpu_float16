module sig_add_abs #(parameter bit EN_OUT_FF = 1'b0) (
  input                            CLK                ,
  input                            RSTn               ,
  input                            DVI                ,
  input                            LARGEST_SIGN       ,
  input               [ 1:0]       OP_SIGNS           ,
  input        signed [ 1:0][41:0] SIGNIFICANDS       ,
  output logic                     SIGN               ,
  output logic signed [41:0]       SUM_OF_SIGNIFICANDS
);

  logic signed [41:0] presum             ;
  logic signed [41:0] sum_of_significands;
  logic               final_sign         ;

  always_comb begin : sig_add_abs
    if (OP_SIGNS[0] ^ OP_SIGNS[1])
      presum = SIGNIFICANDS[0] - SIGNIFICANDS[1];
    else
      presum = SIGNIFICANDS[0] + SIGNIFICANDS[1];

    if (presum[41])
      sum_of_significands = -presum;
    else
      sum_of_significands = presum;

    final_sign = presum[41] ^ LARGEST_SIGN;
  end

  generate
    if (EN_OUT_FF)
      always_ff @(/*negedge RSTn, */posedge CLK)
        /*if (!RSTn) begin
          SIGN <= 1'b0;
          SUM_OF_SIGNIFICANDS <= 'b0;
        end else */begin
          if (DVI) begin
            SIGN                <= final_sign;
            SUM_OF_SIGNIFICANDS <= sum_of_significands;
          end
        end
    else
      always_comb begin
        SIGN = final_sign;
        SUM_OF_SIGNIFICANDS = sum_of_significands;
      end
  endgenerate

endmodule