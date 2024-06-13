module post_add_norm #(parameter bit EN_OUT_FF = 1'b0) (
  input                      CLK                ,
  input                      RSTn               ,
  input                      DVI                ,
  input        signed [ 6:0] LARGEST_EXPONENT   ,
  input        signed [41:0] SUM_OF_SIGNIFICANDS,
  output logic signed [ 6:0] ACTUAL_EXPONENT    ,
  output logic        [10:0] ACTUAL_SIGNIFICAND ,
  output logic        [ 9:0] ACTUAL_OUTPUT_DATA
);

  logic [ 3:0] skip1      ;
  logic [ 5:0] stage1_exp ;
  logic [19:0] stage1_data;

  logic [ 7:0] skip2      ;
  logic [ 5:0] stage2_exp ;
  logic [10:0] stage2_data;

  logic signed [ 6:0] actual_exponent   ;
  logic        [10:0] actual_significand;
  logic        [ 9:0] output_data       ;



  always_comb begin
    for (int i = 0; i < 4; i++)
      if (SUM_OF_SIGNIFICANDS[40 - i*8 -: 8] == {8{SUM_OF_SIGNIFICANDS[41]}})
        skip1[3-i] = 1'b1;
      else
        skip1[3-i] = 1'b0;

    casez (skip1)
      4'b1111: begin
        stage1_data = {SUM_OF_SIGNIFICANDS[9:0], {10{1'b0}}};
        stage1_exp = 6'd32;
      end

      4'b111?: begin
        stage1_data = {SUM_OF_SIGNIFICANDS[17:0], {2{1'b0}}};
        stage1_exp = 6'd24;
      end

      4'b11??: begin
        stage1_data = SUM_OF_SIGNIFICANDS[25 -: 20];
        stage1_exp = 6'd16;
      end

      4'b1???: begin
        stage1_data = SUM_OF_SIGNIFICANDS[33 -: 20];
        stage1_exp = 6'd8;
      end

      default: begin
        stage1_data = SUM_OF_SIGNIFICANDS[41 -: 20];
        stage1_exp = 6'd0;
      end
    endcase
  end

  for (genvar i = 1; i < 9; i++)
    always_comb
      if (stage1_data[18 -: i] == {i{stage1_data[19]}})
        skip2[8-i] = 1'b1;
      else
        skip2[8-i] = 1'b0;

  always_comb begin
    /*  Stage 2
     */
    casez (skip2)
      8'b11111111: begin
        stage2_data = stage1_data[10 -: 11];
        stage2_exp = 8;
      end

      8'b1111111?: begin
        stage2_data = stage1_data[11 -: 11];
        stage2_exp = 7;
      end

      8'b111111??: begin
        stage2_data = stage1_data[12 -: 11];
        stage2_exp = 6;
      end

      8'b11111???: begin
        stage2_data = stage1_data[13 -: 11];
        stage2_exp = 5;
      end

      8'b1111????: begin
        stage2_data = stage1_data[14 -: 11];
        stage2_exp = 4;
      end

      8'b111?????: begin
        stage2_data = stage1_data[15 -: 11];
        stage2_exp = 3;
      end

      8'b11??????: begin
        stage2_data = stage1_data[16 -: 11];
        stage2_exp = 2;
      end

      8'b1???????: begin
        stage2_data = stage1_data[17 -: 11];
        stage2_exp = 1;
      end

      default: begin
        stage2_data = stage1_data[18 -: 11];
        stage2_exp = 0;
      end
    endcase

    actual_exponent = LARGEST_EXPONENT - stage1_exp - stage2_exp;
    actual_significand = stage2_data;

    /*  Снова нормализация
     */
    case (actual_exponent)
      -7'd24 : output_data = actual_significand[10:1] >> 9;
      -7'd23 : output_data = actual_significand[10:1] >> 8;
      -7'd22 : output_data = actual_significand[10:1] >> 7;
      -7'd21 : output_data = actual_significand[10:1] >> 6;
      -7'd20 : output_data = actual_significand[10:1] >> 5;
      -7'd19 : output_data = actual_significand[10:1] >> 4;
      -7'd18 : output_data = actual_significand[10:1] >> 3;
      -7'd17 : output_data = actual_significand[10:1] >> 2;
      -7'd16 : output_data = actual_significand[10:1] >> 1;
      -7'd15 : output_data = actual_significand[10:1];
      default: output_data = actual_significand[ 9:0];
    endcase
  end

  generate
    if (EN_OUT_FF)
      always_ff @(/*negedge RSTn, */posedge CLK)
        /*if (!RSTn) begin
          ACTUAL_EXPONENT <= 'b0;
          ACTUAL_SIGNIFICAND <= 'b0;
          ACTUAL_OUTPUT_DATA <= 'b0;
        end else */begin
          if (DVI) begin
            ACTUAL_EXPONENT    <= actual_exponent;
            ACTUAL_SIGNIFICAND <= actual_significand;
            ACTUAL_OUTPUT_DATA <= output_data;
          end
        end
    else
      always_comb begin
        ACTUAL_EXPONENT    = actual_exponent;
        ACTUAL_SIGNIFICAND = actual_significand;
        ACTUAL_OUTPUT_DATA = output_data;
      end
  endgenerate

endmodule