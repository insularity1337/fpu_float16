module add #(parameter SYNC_STAGES = 0) (
  input                     CLK    ,
  input                     RSTn   ,
  input                     DVI    ,
  input        [ 1:0][ 5:0] DI_TYPE, // 5 - normal, 4 - subnormal, 3 - zero, 2 - infinity, 1 - quiet Nan, 0 - signalling NaN
  input        [ 1:0][15:0] DI     ,
  output logic              DVO    ,
  output logic [ 5:0]       DO_TYPE,
  output logic [15:0]       DO
);

  localparam EN_FINAL_FF = SYNC_STAGES > 0 ? 1'b1 : 1'b0;
  localparam EN_POST_FF  = SYNC_STAGES > 1 ? 1'b1 : 1'b0;
  localparam EN_ADD_FF   = SYNC_STAGES > 2 ? 1'b1 : 1'b0;
  localparam EN_PRE_FF   = SYNC_STAGES > 3 ? 1'b1 : 1'b0;
  localparam EN_RECON_FF = SYNC_STAGES > 4 ? 1'b1 : 1'b0;



  logic signed [ 6:0]       largest_exponent    ;
  logic        [ 1:0][10:0] significand         ;
  logic        [ 6:0]       shift               ;
  logic signed [ 1:0][41:0] true_significands   ;
  logic signed [41:0]       sum_of_significands ;
  logic signed [41:0]       sum_of_significands_;

  logic signed [ 6:0] actual_exponent   ;
  logic        [10:0] actual_significand;

  logic [1:0][1:0] op_signs ;
  logic [1:0]      op_signs_;

  logic sign_pp     ;
  logic sign        ;
  logic largest_sign;

  logic [9:0] output_data;
  logic       actual_sign;
  logic       final_sign ;

  logic [2:0]      extreme_type   ;
  logic [2:0]      extreme_type_  ;
  logic [3:0][2:0] extreme_type_pp;
  logic            extreme_sign   ;
  logic            extreme_sign_  ;
  logic [3:0]      extreme_sign_pp;

  logic signed [1:0][6:0] largest_exponent_pp;
  logic signed [6:0]      largest_exponent_  ;

  logic recon_dv;
  logic pre_dv  ;
  logic add_dv  ;
  logic post_dv ;
  logic final_dv;


  always_comb begin : extr_val_detect
    if (DI_TYPE[0][0] || DI_TYPE[1][0])
      extreme_type[0] = 1'b1;
    else
      extreme_type[0] = 1'b0;

    if ((DI_TYPE[0][1] || DI_TYPE[1][1]) || (DI_TYPE[0][2] && DI_TYPE[1][2] && (DI[0][15] ^ DI[1][15])))
      extreme_type[1] = 1'b1;
    else
      extreme_type[1] = 1'b0;

    if ((DI_TYPE[0][2] && DI_TYPE[1][2] && (DI[0][15] ~^ DI[1][15])) || (DI_TYPE[0][2] || DI_TYPE[1][2]))
      extreme_type[2] = 1'b1;
    else
      extreme_type[2] = 1'b0;

    if (|DI_TYPE[0][2:0])
      extreme_sign = DI[0][15];
    else
      extreme_sign = DI[1][15];
  end

  always_ff @(posedge CLK) begin
    extreme_type_pp <= {extreme_type_pp[2:0], extreme_type};
    extreme_sign_pp <= {extreme_sign_pp[2:0], extreme_sign};
  end

  always_ff @(posedge CLK)
    op_signs <= {op_signs[0], {DI[1][15], DI[0][15]}};

  /*  Get true exponents
   */
  recognize_operands #(EN_RECON_FF) op_recon (
    .CLK             (CLK             ),
    .RSTn            (RSTn            ),
    .DI_TYPE         (DI_TYPE         ),
    .DI              (DI              ),
    .DVI             (recon_dv        ),
    .LARGEST_EXPONENT(largest_exponent),
    .LARGEST_SIGN    (sign            ),
    .SHIFT           (shift           ),
    .SIGNIFICANDS    (significand     )
  );

  always_ff @(posedge CLK)
    sign_pp <= sign;

  always_ff @(posedge CLK)
    largest_exponent_pp <= {largest_exponent_pp[0], largest_exponent};

  /*  Normalize smallest operand
   */
  pre_add_norm #(EN_PRE_FF) pre_norm (
    .CLK              (CLK              ),
    .RSTn             (RSTn             ),
    .DVI              (pre_dv           ),
    .SIGNIFICANDS     (significand      ),
    .SHIFT            (shift            ),
    .TRUE_SIGNIFICANDS(true_significands)
  );

  generate
    if (SYNC_STAGES > 4)
      always_comb begin
        op_signs_    = op_signs[1];
        largest_sign = sign_pp;
      end
    else if (SYNC_STAGES > 3)
      always_comb begin
        op_signs_    = op_signs[0];
        largest_sign = sign_pp;
      end
    else
      always_comb begin
        op_signs_    = {DI[1][15], DI[0][15]};
        largest_sign = sign;
      end
  endgenerate

  /*  Sum of significands
   */
  sig_add_abs #(EN_ADD_FF) add_abs (
    .CLK                (CLK                ),
    .RSTn               (RSTn               ),
    .DVI                (add_dv             ),
    .LARGEST_SIGN       (largest_sign       ),
    .OP_SIGNS           (op_signs_          ),
    .SIGNIFICANDS       (true_significands  ),
    .SIGN               (final_sign         ),
    .SUM_OF_SIGNIFICANDS(sum_of_significands)
  );

  generate
    if (SYNC_STAGES > 3)
      always_comb
        largest_exponent_ = largest_exponent_pp[1];
    else if (SYNC_STAGES > 2)
      always_comb
        largest_exponent_ = largest_exponent_pp[0];
    else
      always_comb
        largest_exponent_ = largest_exponent;
  endgenerate

  /*  < 2^(-14) normalization
   */
  post_add_norm #(EN_POST_FF) post_norm (
    .CLK                (CLK                ),
    .RSTn               (RSTn               ),
    .DVI                (post_dv            ),
    .LARGEST_EXPONENT   (largest_exponent_  ),
    .SUM_OF_SIGNIFICANDS(sum_of_significands),
    .ACTUAL_EXPONENT    (actual_exponent    ),
    .ACTUAL_SIGNIFICAND (actual_significand ),
    .ACTUAL_OUTPUT_DATA (output_data        )
  );

  generate
    if (SYNC_STAGES > 1)
      always_ff @(posedge CLK)
        actual_sign <= final_sign;
    else
      always_comb
        actual_sign = final_sign;
  endgenerate

  generate
    if (SYNC_STAGES > 4)
      always_comb begin
        extreme_type_ = extreme_type_pp[3];
        extreme_sign_ = extreme_sign_pp[3];
      end
    else if (SYNC_STAGES > 3)
      always_comb begin
        extreme_type_ = extreme_type_pp[2];
        extreme_sign_ = extreme_sign_pp[2];
      end
    else if (SYNC_STAGES > 2)
      always_comb begin
        extreme_type_ = extreme_type_pp[1];
        extreme_sign_ = extreme_sign_pp[1];
      end
    else if (SYNC_STAGES > 1)
      always_comb begin
        extreme_type_ = extreme_type_pp[0];
        extreme_sign_ = extreme_sign_pp[0];
      end
    else
      always_comb begin
        extreme_type_ = extreme_type;
        extreme_sign_ = extreme_sign;
      end
  endgenerate

  generate
    if (SYNC_STAGES > 2)
      always_ff @(posedge CLK)
        sum_of_significands_ <= sum_of_significands;
    else
      always_comb
        sum_of_significands_ = sum_of_significands;
  endgenerate

  /*  Final result
   */
  final_result #(EN_FINAL_FF) final_res (
    .CLK                (CLK                 ),
    .RSTn               (RSTn                ),
    .DVI                (final_dv            ),
    .EXTREME_TYPE       (extreme_type_       ),
    .EXTREME_SIGN       (extreme_sign_       ),
    .ACTUAL_SIGN        (actual_sign         ),
    .SUM_OF_SIGNIFICANDS(sum_of_significands_),
    .ACTUAL_EXPONENT    (actual_exponent     ),
    .ACTUAL_SIGNIFICAND (actual_significand  ),
    .ACTUAL_OUTPUT_DATA (output_data         ),
    .DO                 (DO                  ),
    .DO_TYPE            (DO_TYPE             )
  );

  logic [5:0] dv_pp;

  always_comb
    dv_pp[0] = DVI;

  always_ff @(negedge RSTn, posedge CLK)
    if (!RSTn)
      dv_pp[5:1] <= 'b0;
    else
      dv_pp[5:1] <= dv_pp[4:0];

  generate
    if (SYNC_STAGES > 4)
      always_comb begin
        DVO = dv_pp[5];

        recon_dv = dv_pp[0];
        pre_dv   = dv_pp[1];
        add_dv   = dv_pp[2];
        post_dv  = dv_pp[3];
        final_dv = dv_pp[4];
      end
    else if (SYNC_STAGES > 3)
      always_comb begin
        DVO = dv_pp[4];

        recon_dv = 1'b0;
        pre_dv   = dv_pp[0];
        add_dv   = dv_pp[1];
        post_dv  = dv_pp[2];
        final_dv = dv_pp[3];
      end
    else if (SYNC_STAGES > 2)
      always_comb begin
        DVO = dv_pp[3];

        recon_dv = 1'b0;
        pre_dv   = 1'b0;
        add_dv   = dv_pp[0];
        post_dv  = dv_pp[1];
        final_dv = dv_pp[2];
      end
    else if (SYNC_STAGES > 1)
      always_comb begin
        DVO = dv_pp[2];

        recon_dv = 1'b0;
        pre_dv   = 1'b0;
        add_dv   = 1'b0;
        post_dv  = dv_pp[0];
        final_dv = dv_pp[1];
      end
    else if (SYNC_STAGES > 0)
      always_comb begin
        DVO = dv_pp[1];

        recon_dv = 1'b0;
        pre_dv   = 1'b0;
        add_dv   = 1'b0;
        post_dv  = 1'b0;
        final_dv = dv_pp[0];
      end
    else
      always_comb begin
        DVO = dv_pp[0];

        recon_dv = 1'b0;
        pre_dv   = 1'b0;
        add_dv   = 1'b0;
        post_dv  = 1'b0;
        final_dv = 1'b0;
      end
  endgenerate

endmodule