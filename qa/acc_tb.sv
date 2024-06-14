`timescale 1ns/1ps

module acc_tb ();

  logic [ 5:0] a_type        ;
  logic [15:0] a             ;
  logic [15:0] p             ;
  logic        dvi     = 1'b0;
  logic        dvo           ;
  logic [ 5:0] do_type       ;
  int          rel     = 0   ;

  logic clk = 1'b0;
  logic rst = 1'b0;

  function automatic real float16_to_real_normal (input logic [15:0] a);
      real foo = 0.0;
      int exp = 0;
      int start;

      if (int'(a[14:10]) == 0)
          exp = -14;
      else begin
          exp = int'(a[14:10]) - 15;
          foo += real'(2.0**exp);
      end

      for (int i = 1; i < 11; i++) begin
          if (a[10-i])
              foo += real'(2.0**(exp-i));
      end

      if (a[15])
          return -foo;
      else
          return foo;
  endfunction

  function automatic real float42_to_real_normal (input logic [41:0] a);
    real foo = 0.0;
    int exp = 16;

    for (int i = 40; i >=0; i--) begin
      if (a[i] != a[41])
        foo += 2.0**(exp);

      exp--;
    end

    if (a[41])
      return -foo;
    else
      return foo;
  endfunction

  function automatic real abs_float(input real a);
    if (a < 0)
      return -a;
    else
      return a;
  endfunction

  acc #(2) dut (
    .CLK    (clk    ),
    .RSTn   (rst    ),
    .RELEASE(rel[5] ),
    .DVI    (dvi    ),
    .DI_TYPE(a_type ),
    .DI     (a      ),
    .DVO    (dvo    ),
    .DO_TYPE(do_type),
    .DO     (p      )
  );

  int exp;

  real q;
  real qwe = 0.0;
  bit r;

  real a_queue[$];
  bit  r_queue[$];

  initial
    forever
      #5 clk = ~clk;

  initial
    #13 rst = ~rst;

  initial begin
    #10;

    for (int i = 0; i < 30; i++) begin
      @(posedge clk);
      dvi    <= 1'b1;
      a[15] <= $urandom_range(0, 1);
      exp = $urandom_range(0, 30);
      a[ 9: 0] <= $urandom_range(1, 2**(10)-1);

      rel = $urandom_range(0, 32767);

      if (exp == 0)
        a_type <= 6'b010000;
      else
        a_type <= 6'b100000;

      a[14:10] <= exp[4:0];

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      r_queue.push_front(rel[5]);

      @(posedge clk);
      dvi    <= 1'b0;
      a_type <= 'b0;
      a      <= 'b0;
    end


    // @(posedge clk);
    // dvi    <= 1'b1;
    // a[15] <= 1'b0;
    // a[14:10] <= 5'b11110;
    // a[ 9: 0] <= 10'b1111111111;
    // a_type <= 6'b100000;

    // @(posedge clk);
    // dvi    <= 1'b0;
    // a_type <= 'b0;
    // a      <= 'b0;

    // @(posedge clk);
    // dvi    <= 1'b1;
    // a[15] <= 1'b0;
    // a[14:10] <= 5'b01111;
    // a[ 9: 0] <= 10'b0000000000;
    // a_type <= 6'b100000;

    // @(posedge clk);
    // dvi    <= 1'b0;
    // a_type <= 'b0;
    // a      <= 'b0;
  end


  initial begin
    @(posedge clk);
    for (int i = 0; i < 30; i++) begin
      while (dvo !== 1'b1)
        @(posedge clk);

      r = r_queue.pop_back();
      q = a_queue.pop_back();

      if (r == 1'b0)
        qwe += q;
      else
        qwe = q;

      $display("--------------------------------------------------------------------\"?\"");
      $display("a = %5.15f", q);
      $display("Expected value: %5.15f\tp = %5.15f", qwe, float16_to_real_normal(p));

      if ((qwe != float16_to_real_normal(p)) && (qwe < 65504) && (qwe > -65504)) begin
        if (abs_float(qwe) - float42_to_real_normal(dut.storage) != 0.0) begin
          $display("%5.15f", abs_float(qwe) - float42_to_real_normal(dut.storage));
          $display("Ideal: %5.15f", abs_float(qwe));
          $display("Storage %5.15f",float42_to_real_normal(dut.storage));
          $finish;

          if (((qwe > 0.0) && (float16_to_real_normal(p) < 0.0)) || ((qwe < 0.0) && (float16_to_real_normal(p) > 0.0)))
            $finish;
        end
      end
      @(posedge clk);
    end
  end

endmodule