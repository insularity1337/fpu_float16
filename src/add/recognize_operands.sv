module recognize_operands #(parameter bit EN_OUT_FF = 1'b0) (
  input                           CLK             ,
  input                           RSTn            ,
  input               [1:0][ 5:0] DI_TYPE         , // 5 - normal, 4 - subnormal, 3 - zero, 2 - infinity, 1 - quiet Nan, 0 - signalling NaN
  input               [1:0][15:0] DI              ,
  input                           DVI             ,
  output logic signed [6:0]       LARGEST_EXPONENT,
  output logic                    LARGEST_SIGN    ,
  output logic        [6:0]       SHIFT           ,
  output logic        [1:0][10:0] SIGNIFICANDS
);

  logic signed [1:0][ 6:0] true_exponent   ;
  logic signed [1:0][ 6:0] foo             ;
  logic signed [6:0]       largest_exponent;
  logic        [1:0][10:0] significand     ;
  logic        [6:0]       shift           ;
  logic                    sign            ;

  always_comb begin
    true_exponent[0] = signed'({1'b0, DI[0][14:10]}) - 15;
    true_exponent[1] = signed'({1'b0, DI[1][14:10]}) - 15;

    foo[0] = signed'({1'b0, DI[0][14:10]}) - 14 - DI_TYPE[0][5];
    foo[1] = signed'({1'b0, DI[1][14:10]}) - 14 - DI_TYPE[1][5];

    if (signed'(true_exponent[0]) < signed'(true_exponent[1])) begin
      if (DI_TYPE[1][5])
        largest_exponent = true_exponent[1] + 1;
      else
        largest_exponent = true_exponent[1] + 2;

      sign = DI[1][15];

      shift          = foo[1] - foo[0];
      significand[0] = {DI_TYPE[1][5], DI[1][9:0]};
      significand[1] = {DI_TYPE[0][5], DI[0][9:0]};
    end else begin
      if (DI_TYPE[0][5])
        largest_exponent = true_exponent[0] + 1;
      else
        largest_exponent = true_exponent[0] + 2;

      sign = DI[0][15];

      shift          = foo[0] - foo[1];
      significand[0] = {DI_TYPE[0][5], DI[0][9:0]};
      significand[1] = {DI_TYPE[1][5], DI[1][9:0]};
    end
  end

  generate
    if (EN_OUT_FF)
      always_ff @(/*negedge RSTn, */posedge CLK)
        /*if (!RSTn) begin
          LARGEST_EXPONENT <= 'b0;
          LARGEST_SIGN     <= 'b0;
          SHIFT            <= 'b0;
          SIGNIFICANDS     <= 'b0;
        end else */begin
          if (DVI) begin
            LARGEST_EXPONENT <= largest_exponent;
            LARGEST_SIGN     <= sign;
            SHIFT            <= shift;
            SIGNIFICANDS     <= significand;
          end
        end
    else
      always_comb begin
        LARGEST_EXPONENT = largest_exponent;
        LARGEST_SIGN     = sign;
        SHIFT            = shift;
        SIGNIFICANDS     = significand;
      end
  endgenerate

endmodule