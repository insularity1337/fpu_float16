module multiplier #(parameter SYNC_STAGES = 0) (
  input                     CLK   ,
  input                     RSTn  ,
  input                     DVI   ,
  input        [ 1:0][15:0] DI    ,
  output logic              DVO   ,
  output       [ 5:0]       P_TYPE, // 5 - normal, 4 - subnormal, 3 - zero, 2 - infinity, 1 - quiet Nan, 0 - signalling NaN
  output       [15:0]       P
);

  localparam EN_SUBNORM_FF = SYNC_STAGES > 0 ? 1'b1 : 1'b0;
  localparam EN_NORM_FF    = SYNC_STAGES > 1 ? 1'b1 : 1'b0;
  localparam EN_MUL_FF     = SYNC_STAGES > 2 ? 1'b1 : 1'b0;
  localparam EN_CAT_FF     = SYNC_STAGES > 3 ? 1'b1 : 1'b0;

  logic [2:0] normal_type;

  logic [4:0] valid;

  always_comb
    valid[0] = DVI;

  always_ff @(negedge RSTn, posedge CLK)
    if (!RSTn)
      valid[4:1] <= 'b0;
    else
      valid[4:1] <= valid[3:0];

  logic [3:0] sign;

  always_comb
    sign[0] = DI[0][15] ^ DI[1][15];

  always_ff @(/*negedge RSTn, */posedge CLK)
    /*if (!RSTn)
      sign[3:1] <= 'b0;
    else*/
      sign[3:1] <= sign[2:0];

  logic [1:0][5:0] op_type;

  logic        [1:0][10:0] significand;
  logic signed [1:0][ 6:0] exponent   ;

  /*  Classification of input operands & optional syncing
  */
  for (genvar i = 0; i < 2; i++)
    categorizer #(EN_CAT_FF) cat (
      .CLK        (CLK           ),
      .RSTn       (RSTn          ),
      .F          (DI[i]         ),
      .TYPE       (op_type[i]    ),
      .EXPONENT   (exponent[i]   ),
      .SIGNIFICAND(significand[i])
    );

  logic [1:0][15:0] input_data;

  generate
    if (EN_CAT_FF)
      always_ff @(negedge RSTn, posedge CLK)
        if (!RSTn)
          input_data <= 'b0;
        else
          input_data <= DI;
    else
      always_comb
        input_data = DI;
    endgenerate

  logic [ 5:0] extreme_data_type;
  logic [15:0] extreme_data     ;

  extreme_value_detector #(EN_MUL_FF) extreme_det (
    .CLK   (CLK              ),
    .RSTn  (RSTn             ),
    .TYPES (op_type          ),
    .F     (input_data       ),
    .P_TYPE(extreme_data_type),
    .P     (extreme_data     )
  );

  logic [21:0] significand_mul;

  sig_mul #(EN_MUL_FF) significand_multiplier (
    .CLK (CLK            ),
    .RSTn(RSTn           ),
    .F   (significand    ),
    .P   (significand_mul)
  );

  logic signed [1:0][6:0] exp;

  generate
    if (EN_MUL_FF)
      always_ff @(negedge RSTn, posedge CLK)
        if (!RSTn)
          exp <= 'b0;
        else
          exp <= exponent;
    else
      always_comb
        exp = exponent;
  endgenerate

  logic        [10:0] significand_product;
  logic signed [ 6:0] exponent_product   ;
  logic               subnormal_prod     ;

  norm_calc #(EN_NORM_FF) normal_calc (
    .CLK                (CLK                ),
    .RSTn               (RSTn               ),
    .EXPONENT           (exp                ),
    .SIGNIFICAND_MUL    (significand_mul    ),
    .SO                 (subnormal_prod     ),
    .EXPONENT_PRODUCT   (exponent_product   ),
    .SIGNIFICAND_PRODUCT(significand_product),
    .TYPE               (normal_type        )
  );

  logic [ 5:0] extr_data_type;
  logic [15:0] extr_data     ;

  generate
    if (EN_NORM_FF)
      always_ff @(negedge RSTn, posedge CLK)
        if (!RSTn) begin
          extr_data_type <= 'b0;
          extr_data <= 'b0;
        end else begin
          extr_data_type <= extreme_data_type;
          extr_data <= extreme_data;
        end
    else
      always_comb begin
        extr_data_type = extreme_data_type;
        extr_data = extreme_data;
      end
  endgenerate

  logic subnormal_sign;

  generate
    if (SYNC_STAGES > 3)
      always_comb
        subnormal_sign = sign[3];
    else if (SYNC_STAGES > 2)
      always_comb
        subnormal_sign = sign[2];
    else if (SYNC_STAGES > 1)
      always_comb
        subnormal_sign = sign[1];
    else
      always_comb
        subnormal_sign = sign[0];
  endgenerate

  subnorm_calc #(EN_SUBNORM_FF) subnormal_calc (
    .CLK                (CLK                ),
    .RSTn               (RSTn               ),
    .EXTR_TYPE          (extr_data_type     ),
    .EXTR_DATA          (extr_data          ),
    .SUB_V              (subnormal_prod     ),
    .SIGN               (subnormal_sign     ),
    .NORMAL_TYPE        (normal_type        ),
    .EXPONENT_PRODUCT   (exponent_product   ),
    .SIGNIFICAND_PRODUCT(significand_product),
    .P_TYPE             (P_TYPE             ),
    .P                  (P                  )
  );

  generate
    if (SYNC_STAGES > 3)
      always_comb
        DVO = valid[4];
    else if (SYNC_STAGES > 2)
      always_comb
        DVO = valid[3];
    else if (SYNC_STAGES > 1)
      always_comb
        DVO = valid[2];
    else if (SYNC_STAGES > 0)
      always_comb
        DVO = valid[1];
    else
      always_comb
        DVO = valid[0];
  endgenerate

endmodule