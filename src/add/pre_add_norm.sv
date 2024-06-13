module pre_add_norm #(parameter bit EN_OUT_FF = 1'b0) (
  input                           CLK              ,
  input                           RSTn             ,
  input                           DVI              ,
  input               [1:0][10:0] SIGNIFICANDS     ,
  input               [6:0]       SHIFT            ,
  output logic signed [1:0][41:0] TRUE_SIGNIFICANDS
);

  logic signed [1:0][41:0] true_significands;

  always_comb begin
    true_significands[0][41]    = 1'b0; // sign bit
    true_significands[0][40]    = 1'b0; // overflow bit
    true_significands[0][39:29] = SIGNIFICANDS[0]; // actual significand
    true_significands[0][28:0]  = 'b0;

    true_significands[1][41]   = 1'b0; // sign bit
    true_significands[1][40]   = 1'b0; // overflow bit
    true_significands[1][39:0] = {SIGNIFICANDS[1], 29'd0} >> SHIFT; // normalized significand
  end

  generate
    if (EN_OUT_FF)
      always_ff @(/*negedge RSTn, */posedge CLK)
        /*if (!RSTn)
          TRUE_SIGNIFICANDS <= 'b0;
        else*/begin
          if (DVI)
            TRUE_SIGNIFICANDS <= true_significands;
        end
    else
      always_comb
        TRUE_SIGNIFICANDS = true_significands;
  endgenerate

endmodule