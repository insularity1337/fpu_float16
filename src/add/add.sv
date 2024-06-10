module add (
  input                     CLK    ,
  input                     RSTn   ,
  input                     DVI    ,
  input        [ 1:0][ 5:0] DI_TYPE, // 5 - normal, 4 - subnormal, 3 - zero, 2 - infinity, 1 - quiet Nan, 0 - signalling NaN
  input        [ 1:0][15:0] DI     ,
  output logic              DVO    ,
  output logic [ 5:0]       DO_TYPE,
  output logic [15:0]       DO
);

  logic signed [ 1:0][ 6:0] true_exponent      ;
  logic signed [ 6:0]       largest_exponent   ;
  logic        [ 1:0][10:0] significand        ;
  logic        [ 6:0]       shift              ;
  logic signed [ 1:0][41:0] true_significands  ;
  logic signed [41:0]       presum             ;
  logic signed [41:0]       sum_of_significands;

  logic sign;

  logic signed [ 6:0] actual_exponent   ;
  logic        [10:0] actual_significand;

  logic [ 3:0] skip1      ;
  logic [ 5:0] stage1_exp ;
  logic [19:0] stage1_data;

  logic [ 7:0] skip2      ;
  logic [ 5:0] stage2_exp ;
  logic [10:0] stage2_data;


  logic overflow ;
  logic zero     ;
  logic subnormal;

  logic signed [1:0][6:0] foo;

  logic [9:0] output_data;

  logic final_sign;


  always_comb begin
    /*  Получаем "настоящую" экспоненту
    */
    // if (DI_TYPE[0][5])
      true_exponent[0] = signed'({1'b0, DI[0][14:10]}) - 15;
    // else
    //   true_exponent[0] = signed'({1'b0, DI[0][14:10]}) - 14;

    // if (DI_TYPE[1][5])
      true_exponent[1] = signed'({1'b0, DI[1][14:10]}) - 15;
    // else
    //   true_exponent[1] = signed'({1'b0, DI[1][14:10]}) - 14;

    if (DI_TYPE[0][5])
      foo[0] = signed'({1'b0, DI[0][14:10]}) - 15;
    else
      foo[0] = signed'({1'b0, DI[0][14:10]}) - 14;

    if (DI_TYPE[1][5])
      foo[1] = signed'({1'b0, DI[1][14:10]}) - 15;
    else
      foo[1] = signed'({1'b0, DI[1][14:10]}) - 14;

    /*  Находим наибольшую экспоненту и определяем на сколько бит сдвигать мантиссу
    */
    if (signed'(true_exponent[0]) < signed'(true_exponent[1])) begin
      if (DI_TYPE[1][5])
        largest_exponent = true_exponent[1] + 1;
      else
        largest_exponent = true_exponent[1] + 2;

      sign = DI[1][15];

      // shift          = true_exponent[1] - true_exponent[0];
      shift          = foo[1] - foo[0];
      significand[0] = {DI_TYPE[1][5], DI[1][9:0]};
      significand[1] = {DI_TYPE[0][5], DI[0][9:0]};
    end else begin
      if (DI_TYPE[0][5])
        largest_exponent = true_exponent[0] + 1;
      else
        largest_exponent = true_exponent[0] + 2;

      sign = DI[0][15];

      // shift          = true_exponent[0] - true_exponent[1];
      shift          = foo[0] - foo[1];
      significand[0] = {DI_TYPE[0][5], DI[0][9:0]};
      significand[1] = {DI_TYPE[1][5], DI[1][9:0]};
    end

    /*  Нормализация операндов
    */
    true_significands[0][41]    = 1'b0; // sign bit
    true_significands[0][40]    = 1'b0; // overflow bit
    true_significands[0][39:29] = significand[0]; // actual significand
    true_significands[0][28:0]  = 'b0;

    true_significands[1][41]   = 1'b0; // sign bit
    true_significands[1][40]   = 1'b0; // overflow bit
    true_significands[1][39:0] = {significand[1], 29'd0} >> shift; // normalized significand

    /*  Складываем мантиссы
    */
    if (DI[0][15] ^ DI[1][15])
      presum = true_significands[0] - true_significands[1];
    else
      presum = true_significands[0] + true_significands[1];

    if (presum[41])
      sum_of_significands = -presum;
    else
      sum_of_significands = presum;

    final_sign = presum[41] ^ sign;

    /*  Underflow случай
     */
    for (int i = 0; i < 4; i++)
      if (sum_of_significands[40 - i*8 -: 8] == {8{sum_of_significands[41]}})
        skip1[3-i] = 1'b1;
      else
        skip1[3-i] = 1'b0;

    casez (skip1)
      4'b1111: begin
        stage1_data = {sum_of_significands[9:0], {10{1'b0}}};
        stage1_exp = 6'd32;
      end

      4'b111?: begin
        stage1_data = {sum_of_significands[17:0], {2{1'b0}}};
        stage1_exp = 6'd24;
      end

      4'b11??: begin
        stage1_data = sum_of_significands[25 -: 20];
        stage1_exp = 6'd16;
      end

      4'b1???: begin
        stage1_data = sum_of_significands[33 -: 20];
        stage1_exp = 6'd8;
      end

      default: begin
        stage1_data = sum_of_significands[41 -: 20];
        stage1_exp = 6'd0;
      end
    endcase

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

    actual_exponent = largest_exponent - stage1_exp - stage2_exp;
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

    DO[15] = final_sign;

    if (overflow) begin
      DO[14:10] = 5'b11111;
      DO[ 9: 0] = 10'h000;
      DO_TYPE = 6'b000100;
    end else if (zero) begin
      DO[14:0] = 15'h0000;
      DO_TYPE = 6'b001000;
    end else if (subnormal) begin
      DO[14:10] = 5'b00000;
      DO[ 9: 0] = output_data;
      DO_TYPE = 6'b010000;
    end else begin
      DO[14:10] = actual_exponent + 15;
      DO[ 9: 0] = output_data;
      DO_TYPE = 6'b100000;
    end
  end

  for (genvar i = 1; i < 9; i++)
    always_comb
      if (stage1_data[18 -: i] == {i{stage1_data[19]}})
        skip2[8-i] = 1'b1;
      else
        skip2[8-i] = 1'b0;

  always_comb begin
    DVO = DVI;

    if (((signed'(actual_exponent) == 7'sd15) && (&actual_significand) && |sum_of_significands[28:0]) || (signed'(actual_exponent) > 7'sd15))
      overflow = 1'b1;
    else
      overflow = 1'b0;

    if (((signed'(actual_exponent) == -7'sd24) && (DO[9:0] == 'b0) && (sum_of_significands == 'b0)) || (signed'(actual_exponent) < -7'sd24))
      zero = 1'b1;
    else
      zero = 1'b0;

    if (actual_exponent < -14)
      subnormal = 1'b1;
    else
      subnormal = 1'b0;
  end

endmodule