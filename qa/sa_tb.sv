`timescale 1ns/1ps

module sa_tb ();

  localparam DIMENSION = 4;

  logic                                      clk   = 1'b0;
  logic                                      rst_n = 1'b0;
  logic [DIMENSION-1:0]                      dvi         ;
  logic [          1:0][DIMENSION-1:0][15:0] di          ;
  logic                                      dvo         ;
  logic [DIMENSION-1:0]                      dout        ;

  sa #(DIMENSION) dut (
    .CLK (clk  ),
    .RSTn(rst_n),
    .DVI (dvi  ),
    .DI  (di   ),
    .DVO (dvo  ),
    .DO  (dout )
  );

  initial
    forever
      #5 clk = ~clk;

  initial
    #13 rst_n = ~rst_n;

  initial begin
    repeat(10)
      @(posedge clk);

    repeat(2) begin
      @(posedge clk);
      dvi <= 4'b0001;
      di[0] <= {16'h0000, 16'h0000, 16'h0000, 16'h1A14};
      di[1] <= {16'h0000, 16'h0000, 16'h0000, 16'h1B41};

      @(posedge clk);
      dvi <= 4'b0011;
      di[0] <= {16'h0000, 16'h0000, 16'h1A24, 16'h1A13};
      di[1] <= {16'h0000, 16'h0000, 16'h1B42, 16'h1B31};

      @(posedge clk);
      dvi <= 4'b0111;
      di[0] <= {16'h0000, 16'h1A34, 16'h1A23, 16'h1A12};
      di[1] <= {16'h0000, 16'h1B43, 16'h1B32, 16'h1B21};

      @(posedge clk);
      dvi <= 4'b1111;
      di[0] <= {16'h1A44, 16'h1A33, 16'h1A22, 16'h1A11};
      di[1] <= {16'h1B44, 16'h1B33, 16'h1B22, 16'h1B11};

      @(posedge clk);
      dvi <= 4'b1110;
      di[0] <= {16'h1A43, 16'h1A32, 16'h1A21, 16'h0000};
      di[1] <= {16'h1B34, 16'h1B23, 16'h1B12, 16'h0000};

      @(posedge clk);
      dvi <= 4'b1100;
      di[0] <= {16'h1A42, 16'h1A31, 16'h0000, 16'h0000};
      di[1] <= {16'h1B24, 16'h1B13, 16'h0000, 16'h0000};

      @(posedge clk);
      dvi <= 4'b1000;
      di[0] <= {16'h1A41, 16'h0000, 16'h0000, 16'h0000};
      di[1] <= {16'h1B14, 16'h0000, 16'h0000, 16'h0000};

      @(posedge clk);
      dvi <= 4'b0000;
      di[0] <= {16'h0000, 16'h0000, 16'h0000, 16'h0000};
      di[1] <= {16'h0000, 16'h0000, 16'h0000, 16'h0000};

      repeat($urandom_range(10,20))
        @(posedge clk);
    end
  end

endmodule