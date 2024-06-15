module norm_calc #(parameter bit EN_OUT_FF = 1'b0) (
  input                           CLK                ,
  input                           RSTn               ,
  input        signed [ 1:0][6:0] EXPONENT           ,
  input               [21:0]      SIGNIFICAND_MUL    ,
  output logic                    SO                 , // Subnormal output
  output logic signed [ 6:0]      EXPONENT_PRODUCT   ,
  output logic        [10:0]      SIGNIFICAND_PRODUCT,
  output logic        [ 2:0]      TYPE
);

  logic signed [ 6:0] exp_prod           ;
  logic signed [ 6:0] exponent_product   ;
  logic        [10:0] sig_prod           ;
  logic        [10:0] significand_product;

  logic prod_zero;
  logic prod_sub ;
  logic prod_inf ;

  always_comb begin
    exp_prod = EXPONENT[0] + EXPONENT[1] + SIGNIFICAND_MUL[21];

    if (SIGNIFICAND_MUL[21])
      sig_prod = SIGNIFICAND_MUL[21 -: 11];
    else
      sig_prod = SIGNIFICAND_MUL[20 -: 11];

    if (exp_prod < -24)
      prod_zero = 1'b1;
    else
      prod_zero = 1'b0;

    if ((exp_prod < -14) && (exp_prod > -25))
      prod_sub = 1'b1;
    else
      prod_sub = 1'b0;

    if (exp_prod > 15)
      prod_inf = 1'b1;
    else
      prod_inf = 1'b0;
  end

  always_comb begin
    case ({prod_zero, prod_sub, prod_inf})
      3'b001: begin
        exponent_product = 6'b111111;
        significand_product = 11'b00000000000;
      end

      3'b010: begin
        exponent_product = exp_prod;
        significand_product = sig_prod;
      end

      3'b100: begin
        exponent_product = 6'b000000;
        significand_product = 11'b00000000000;
      end

      default: begin
        exponent_product = exp_prod + 15;
        significand_product = sig_prod;
      end
    endcase
  end

  generate
    if (EN_OUT_FF)
      always_ff @(/*negedge RSTn,*/ posedge CLK)
        /*if (!RSTn) begin
          SO                  <= 1'b0;
          EXPONENT_PRODUCT    <= 'b0;
          SIGNIFICAND_PRODUCT <= 'b0;
        end else*/ begin
          SO                  <= prod_sub;
          EXPONENT_PRODUCT    <= exponent_product;
          SIGNIFICAND_PRODUCT <= significand_product;
          TYPE                <= {prod_zero, prod_sub, prod_inf};
        end
    else
      always_comb begin
        SO                  = prod_sub;
        EXPONENT_PRODUCT    = exponent_product;
        SIGNIFICAND_PRODUCT = significand_product;
        TYPE                = {prod_zero, prod_sub, prod_inf};
      end
  endgenerate

endmodule