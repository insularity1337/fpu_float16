module mac #(
  parameter MULTIPIER_SYNC_STAGES   = 0,
  parameter ACCUMULATOR_SYNC_STAGES = 0
) (
  input               CLK    ,
  input               RSTn   ,
  input               RELEASE,
  input               DVI    ,
  input  [ 1:0][15:0] DI     ,
  output              DVO    ,
  output [ 5:0]       DO_TYPE,
  output [15:0]       DO
);

  logic [MULTIPIER_SYNC_STAGES-1:0] release_pp ;
  logic [                      5:0] mul_do_type;
  logic [                     15:0] mul_do     ;
  logic                             acc_release;

  multiplier #(MULTIPIER_SYNC_STAGES) mul (
    .CLK   (CLK        ),
    .RSTn  (RSTn       ),
    .DVI   (DVI        ),
    .DI    (DI         ),
    .DVO   (mul_dvo    ),
    .P_TYPE(mul_do_type),
    .P     (mul_do     )
  );

  always_ff @(posedge CLK)
    release_pp <= {release_pp[MULTIPIER_SYNC_STAGES-2:0], RELEASE};

  generate
    if (MULTIPIER_SYNC_STAGES == 0)
      always_comb
        acc_release = RELEASE;
    else
      always_comb
        acc_release = release_pp[MULTIPIER_SYNC_STAGES-1];
  endgenerate

  acc #(ACCUMULATOR_SYNC_STAGES) accum (
    .CLK    (CLK        ),
    .RSTn   (RSTn       ),
    .DVI    (mul_dvo    ),
    .RELEASE(acc_release),
    .DI_TYPE(mul_do_type),
    .DI     (mul_do     ),
    .DVO    (DVO        ),
    .DO_TYPE(DO_TYPE    ),
    .DO     (DO         )
  );

endmodule