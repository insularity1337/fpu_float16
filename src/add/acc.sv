module acc #(
  parameter             SYNC_STAGES = 0   ,
  parameter bit         MODE        = 1'b0,
  parameter logic [5:0] RELEASE_CNT = 6'd2
) (
  input               CLK    ,
  input               RSTn   ,
  input               DVI    ,
  input               RELEASE,
  input        [ 5:0] DI_TYPE,
  input        [15:0] DI     ,
  output logic        DVO    ,
  output logic [ 5:0] DO_TYPE,
  output logic [15:0] DO
);

  parameter EN_FINAL_FF = SYNC_STAGES > 0 ? 1'b1 : 1'b0;
  parameter EN_POST_FF  = SYNC_STAGES > 1 ? 1'b1 : 1'b0;

  logic [10:0] presig          ;
  logic [11:0] new_significand_;

  logic signed [41:0] new_significand;
  logic signed [41:0] significand;

  logic signed [41:0] sig_sum;
  logic signed [41:0] sig_prod;

  logic signed [ 6:0] actual_exponent   ;
  logic        [10:0] actual_significand;
  logic        [ 9:0] output_data       ;

  logic [4:0] shift;

  logic [1:0] sign       ;
  logic       actual_sign;

  logic [4:0] dv_pp   ;
  logic       post_dv ;
  logic       final_dv;

  logic [2:0]      extreme_type   ;
  logic [2:0]      extreme_type_  ;
  logic [1:0][2:0] extreme_type_pp;
  logic            extreme_sign   ;
  logic            extreme_sign_  ;
  logic [1:0]      extreme_sign_pp;

  logic [15:0] input_data;

  logic output_valid;

  logic [5:0] rel_cnt ;
  logic       rel     ;
  logic       release_;

  always_ff @(negedge RSTn, posedge CLK)
    if (!RSTn)
      rel_cnt <= 6'd0;
    else begin
      if (DVI)
        if (rel_cnt < RELEASE_CNT-1)
          rel_cnt <= rel_cnt + 1;
        else
          rel_cnt <= 6'd0;
    end

  always_ff @(negedge RSTn, posedge CLK)
    if (!RSTn)
      rel <= 1'b0;
    else begin
      if (DVI)
        if (rel_cnt == RELEASE_CNT-1)
          rel <= 1'b1;
        else
          rel <= 1'b0;
    end

  generate
    if (MODE)
      always_comb
        release_ = rel;
    else
      always_comb
        release_ = RELEASE;
  endgenerate

  always_ff @(negedge RSTn, posedge CLK)
    if (!RSTn) begin
      extreme_type <= 3'b000;
      extreme_sign <= 1'b0;
    end else if (DVI && (release_/*RELEASE*/ || (!(|extreme_type) && |DI_TYPE[2:0]))) begin
      extreme_type <= DI_TYPE;
      extreme_sign <= DI[15];
    end

  always_comb begin
    extreme_type_pp[0] = extreme_type;
    extreme_sign_pp[0] = extreme_sign;
  end

  always_ff @(posedge CLK) begin
    extreme_type_pp[1] <= extreme_type_pp[0];
    extreme_sign_pp[1] <= extreme_sign_pp[0];
  end

  always_comb
    dv_pp[0] = DVI;

  always_ff @(posedge CLK)
    dv_pp[4:1] <= dv_pp[3:0];

  always_comb begin
    // +/- zero exception
    if (DI_TYPE[3])
      input_data = 16'h0000;
    else
      input_data = DI;

    presig[10] = DI_TYPE[5];
    presig[9:0] = /*DI*/input_data[9:0];

    if (/*DI*/input_data[15])
      new_significand_ = (presig[10:0] ^ {11{1'b1}}) + 1;
    else
      new_significand_ = presig;

    new_significand_[11] = /*DI*/input_data[15];

    shift = 30 - DI_TYPE[4] - /*DI*/input_data[14:10];

    new_significand[41:0] = signed'({new_significand_[11], new_significand_, 29'd0}) >>> shift;

    sig_sum = sig_prod + new_significand;
  end

  always_ff @(negedge RSTn, posedge CLK)
    if (!RSTn) begin
      sig_prod <= 'b0;
    end else if (DVI) begin
      if (release_/*RELEASE*/)
        sig_prod <= new_significand;
      else
        sig_prod <= sig_sum;
    end

  always_comb
    if (sig_prod[41])
      significand = -sig_prod;
    else
      significand = sig_prod;

  post_add_norm #(EN_POST_FF) post_norm (
    .CLK                (CLK               ),
    .RSTn               (RSTn              ),
    .DVI                (post_dv           ),
    .LARGEST_EXPONENT   (16                ),
    .SUM_OF_SIGNIFICANDS(significand       ),
    .ACTUAL_EXPONENT    (actual_exponent   ),
    .ACTUAL_SIGNIFICAND (actual_significand),
    .ACTUAL_OUTPUT_DATA (output_data       )
  );

  always_ff @(posedge CLK)
    sign <= {sign[0], sig_prod[41]/*RELEASE ? new_significand[41] : sig_sum[41]*/};

  generate
    if (SYNC_STAGES > 2)
      always_comb
        actual_sign = sign[1];
    else if (SYNC_STAGES > 1)
      always_comb
        actual_sign = sign[0];
    else
      always_comb
        actual_sign = sig_prod[41]/*sig_sum[41]*/;
  endgenerate

  generate
    if (SYNC_STAGES > 1)
      always_comb begin
        extreme_type_ = extreme_type_pp[1];
        extreme_sign_ = extreme_sign_pp[1];
      end
    else
      always_comb begin
        extreme_type_ = extreme_type_pp[0];
        extreme_sign_ = extreme_sign_pp[0];
      end
  endgenerate

  final_result #(EN_FINAL_FF) final_res (
    .CLK                (CLK               ),
    .RSTn               (RSTn              ),
    .DVI                (final_dv          ),
    .EXTREME_TYPE       (extreme_type_     ),
    .EXTREME_SIGN       (extreme_sign_     ),
    .ACTUAL_SIGN        (actual_sign       ),
    .SUM_OF_SIGNIFICANDS(significand       ),
    .ACTUAL_EXPONENT    (actual_exponent   ),
    .ACTUAL_SIGNIFICAND (actual_significand),
    .ACTUAL_OUTPUT_DATA (output_data       ),
    .DO                 (DO                ),
    .DO_TYPE            (DO_TYPE           )
  );

  generate
    if (SYNC_STAGES > 1)
      always_comb begin
        post_dv      = dv_pp[1];
        final_dv     = dv_pp[2];
        output_valid = dv_pp[3];
      end
    else if (SYNC_STAGES > 0)
      always_comb begin
        post_dv      = 1'b0;
        final_dv     = dv_pp[1];
        output_valid = dv_pp[2];
      end
    else
      always_comb begin
        post_dv      = 1'b0;
        final_dv     = 1'b0;
        output_valid = dv_pp[1];
      end
  endgenerate

  logic [5:0] valid_cnt;

  always_ff @(negedge RSTn, posedge CLK)
    if (!RSTn)
      valid_cnt <= 6'd0;
    else begin
      if (output_valid)
        if (valid_cnt < RELEASE_CNT-1)
          valid_cnt <= valid_cnt + 1;
        else
          valid_cnt <= 6'd0;
    end

  generate
    if (MODE)
      always_comb
        if (output_valid && (valid_cnt == RELEASE_CNT-1))
          DVO = 1'b1;
        else
          DVO = 1'b0;
    else
      always_comb
        DVO = output_valid;
  endgenerate


`ifdef SIM
  logic [2:0][41:0] storage_pp;
  logic signed [41:0] storage;

  always_comb
    storage_pp[0] = significand;

  always_ff @(posedge CLK)
    storage_pp[2:1] <= storage_pp[1:0];

  generate
    if (SYNC_STAGES > 1)
      always_comb
        storage = storage_pp[2];
    else if (SYNC_STAGES > 0)
      always_comb
        storage = storage_pp[1];
    else
      always_comb
        storage = storage_pp[0];
  endgenerate
`endif
endmodule