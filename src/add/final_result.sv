module final_result #(parameter bit EN_OUT_FF = 1'b0) (
  input                      CLK                ,
  input                      RSTn               ,
  input                      DVI                ,
  input               [ 2:0] EXTREME_TYPE       ,
  input                      EXTREME_SIGN       ,
  input                      ACTUAL_SIGN        ,
  input        signed [41:0] SUM_OF_SIGNIFICANDS,
  input        signed [ 6:0] ACTUAL_EXPONENT    ,
  input               [10:0] ACTUAL_SIGNIFICAND ,
  input               [ 9:0] ACTUAL_OUTPUT_DATA ,
  output logic        [15:0] DO                 ,
  output logic        [ 5:0] DO_TYPE
);

  logic overflow, zero, subnormal;

  logic [15:0] output_data ;
  logic [ 5:0] output_type ;

  always_comb begin
    if (((signed'(ACTUAL_EXPONENT) == 7'sd15) && (&ACTUAL_SIGNIFICAND) && |SUM_OF_SIGNIFICANDS[28:0]) || (signed'(ACTUAL_EXPONENT) > 7'sd15))
      overflow = 1'b1;
    else
      overflow = 1'b0;

    if (((signed'(ACTUAL_EXPONENT) == -7'sd24) && (ACTUAL_OUTPUT_DATA[9:0] == 'b0) && (SUM_OF_SIGNIFICANDS == 'b0)) || (signed'(ACTUAL_EXPONENT) < -7'sd24))
      zero = 1'b1;
    else
      zero = 1'b0;

    if (ACTUAL_EXPONENT < -14)
      subnormal = 1'b1;
    else
      subnormal = 1'b0;

    if (|EXTREME_TYPE)
      output_data[15] = EXTREME_SIGN;
    else
      output_data[15] = ACTUAL_SIGN;

    /*  SIGN?
     */
    if (EXTREME_TYPE[0]) begin
      output_data[14:10] = 5'b11111;
      output_data[ 9: 0] = 10'hFFF;
      output_type = 6'b000001;
    end else if (EXTREME_TYPE[1]) begin
      output_data[14:10] = 5'b11111;
      output_data[    9] = 1'b1;
      output_data[ 8: 0] = 10'hFFF;
      output_type = 6'b000010;;
    end else if (overflow || EXTREME_TYPE[2]) begin
      output_data[14:10] = 5'b11111;
      output_data[ 9: 0] = 10'h000;
      output_type = 6'b000100;
    end else if (zero) begin
      output_data[14:0] = 15'h0000;
      output_type = 6'b001000;
    end else if (subnormal) begin
      output_data[14:10] = 5'b00000;
      output_data[ 9: 0] = ACTUAL_OUTPUT_DATA;
      output_type = 6'b010000;
    end else begin
      output_data[14:10] = ACTUAL_EXPONENT + 15;
      output_data[ 9: 0] = ACTUAL_OUTPUT_DATA;
      output_type = 6'b100000;
    end
  end

  generate
    if (EN_OUT_FF)
      always_ff @(/*negedge RSTn, */posedge CLK)
        /*if (!RSTn) begin
          DO      <= 'b0;
          DO_TYPE <= 'b0;
        end else */begin
          if (DVI) begin
            DO      <= output_data;
            DO_TYPE <= output_type;
          end
        end
    else
      always_comb begin
        DO      = output_data;
        DO_TYPE = output_type;
      end
  endgenerate

endmodule