module sa #(parameter DIMENSION = 2) (
  input                                             CLK ,
  input                                             RSTn,
  input        [DIMENSION-1:0]                      DVI ,
  input        [          1:0][DIMENSION-1:0][15:0] DI  ,
  output logic [DIMENSION-1:0][DIMENSION-1:0]       DVO ,
  output logic [DIMENSION-1:0][DIMENSION-1:0][15:0] DO
);

  logic [DIMENSION-1:0][DIMENSION-1:0][15:0] row_pp   ;
  logic [DIMENSION-1:0][DIMENSION-1:0][15:0] column_pp;
  logic [DIMENSION-1:0][DIMENSION-1:0]       dv_pp    ;

  for (genvar i = 0; i < DIMENSION; i++) begin
    always_comb
      row_pp[i][0] = DI[0][i];

    always_ff @(posedge CLK)
      row_pp[i][DIMENSION-1:1] <= row_pp[i][DIMENSION-2:0];

    always_comb
      column_pp[i][0] = DI[1][i];

    always_ff @(posedge CLK)
      column_pp[i][DIMENSION-1:1] <= column_pp[i][DIMENSION-2:0];

    always_comb
      dv_pp[i][0] = DVI[i];

    always_ff @(posedge CLK)
      dv_pp[i][DIMENSION-1:1] <= dv_pp[i][DIMENSION-2:0];
  end

  logic [DIMENSION-1:0][DIMENSION-1:0]       dvo ;
  logic [DIMENSION-1:0][DIMENSION-1:0][15:0] dout;

  logic        dvo_1_1, dvo_1_2, dvo_2_1, dvo_2_2;
  logic [15:0] do_1_1, do_1_2, do_2_1, do_2_2;

  for (genvar i = 0; i < DIMENSION; i++)
    for (genvar j = 0; j < DIMENSION; j++) begin
      mac #(4,2,1'b1,DIMENSION) mul_n_acc (
        .CLK    (CLK                            ),
        .RSTn   (RSTn                           ),
        .RELEASE(1'b0                           ),
        .DVI    (dv_pp[i][j]                    ),
        .DI     ({column_pp[j][i], row_pp[i][j]}),
        .DVO    (DVO[i][j]                      ),
        .DO_TYPE(                               ),
        .DO     (DO[i][j]                       )
      );
    end

endmodule