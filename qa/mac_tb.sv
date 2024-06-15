`timescale 1ns/1ps

module mac_tb ();

  localparam ITER = 10000;

  localparam real LOWEST_SUBNORMAL_NUMBER = 2.0 ** (-23);
  localparam MUL_SYNC_STAGES = 4;
  localparam ACC_SYNC_STAGES = 2;

  function automatic real float16_to_real_normal(input logic [15:0] a);
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

  function automatic real abs_float(input real a);
    if (a < 0)
      return -a;
    else
      return a;
  endfunction

  logic        clk       = 1'b0;
  logic        rst_n     = 1'b0;
  logic        rel       = 1'b0;
  logic        dvi             ;
  logic [15:0] a               ;
  logic [15:0] b               ;
  logic        dvo             ;
  logic [ 5:0] dout_type       ;
  logic [15:0] dout            ;

  mac #(MUL_SYNC_STAGES, ACC_SYNC_STAGES) dut (
    .CLK    (clk      ),
    .RSTn   (rst_n    ),
    .RELEASE(rel      ),
    .DVI    (dvi      ),
    .DI     ({b, a}   ),
    .DVO    (dvo      ),
    .DO_TYPE(dout_type),
    .DO     (dout     )
  );

  initial
    forever
      #5 clk = ~clk;

  initial
    #13 rst_n = ~rst_n;

  int delay = 0;
  int exp;
  int sig;
  real a_r, b_r, mul_prod;
  real acc_prod = 0.0;

  real a_q [$];
  real b_q [$];
  bit r_q [$];
  real mul_q [$];
  real acc_q [$];
  bit overflow_q [$];
  bit overflow_q_ [$];

  bit overflow = 1'b0;

  initial begin
    repeat(10)
      @(posedge clk);

    repeat(ITER) begin
      @(posedge clk);
      dvi <= 1'b1;

      if (overflow)
        rel <= 1'b1;
      else
        rel <= 1'b0;

      exp = $urandom_range(0, 30);
      sig = $urandom_range(0, 1023);

      a[   15] <= $urandom_range(0, 1);
      a[14:10] <= exp[4:0];
      a[ 9: 0] <= sig[9:0];

      exp = $urandom_range(0, 30);
      sig = $urandom_range(0, 1023);

      b[   15] <= $urandom_range(0, 1);
      b[14:10] <= exp[4:0];
      b[ 9: 0] <= sig[9:0];

      @(negedge clk);
      a_r = float16_to_real_normal(a);
      b_r = float16_to_real_normal(b);
      mul_prod = a_r * b_r;
      if (rel == 1'b0)
        acc_prod += mul_prod;
      else
        acc_prod = mul_prod;

      if ((acc_prod > 65504.0) || (acc_prod < -65504.0) || (mul_prod > 65504.0) || (mul_prod < -65504.0))
        overflow = 1'b1;
      else
        overflow = 1'b0;

      overflow_q.push_front(overflow);
      overflow_q_.push_front(overflow);
      r_q.push_front(rel);
      a_q.push_front(a_r);
      b_q.push_front(b_r);
      mul_q.push_front(mul_prod);
      acc_q.push_front(acc_prod);

      delay = $urandom_range(0, 15);

      if (delay > 0)
        repeat(delay) begin
          @(posedge clk);
          dvi <= 1'b0;
          a <= 'b0;
          b <= 'b0;
          rel <= 1'b0;
        end
    end
  end

  real foo            ;
  real bar            ;
  real diff_mul  = 0.0;
  real diff_mul_ = 0.0;
  real diff_acc  = 0.0;
  real diff_acc_ = 0.0;
  real a_, b_;

  bit over = 1'b0;
  bit over_ = 1'b0;

  initial begin
    repeat(ITER) begin
      while(dut.mul_dvo !== 1'b1)
        @(negedge clk);

      a_   = a_q.pop_back();
      b_   = b_q.pop_back();
      foo  = mul_q.pop_back();
      over = overflow_q.pop_back();

      $display("-------------------------------------------------------------------------");
      $display("Multiplication product (ideal):\t%5.15f", foo);
      $display("Multiplication product (real):\t%5.15f", float16_to_real_normal(dut.mul_do));
      $display("Multiplication diff:\t\t\t%5.15f", foo - float16_to_real_normal(dut.mul_do));
      diff_mul = abs_float((foo - float16_to_real_normal(dut.mul_do)))/abs_float(foo);
      diff_mul_ = foo - float16_to_real_normal(dut.mul_do);

      $display("\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tMultiplication diff (percentage):\t%5.15f", diff_mul);
      $display("\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tTime: %t", $time());

      if ((((foo > 0.0) && (foo > 65504.0) && (dut.mul_do == 16'b0_11111_0000000000) && (dut.mul_do_type == 6'b000100)) || ((foo < 0.0) && (foo < -65504.0) && (dut.mul_do == 16'b1_11111_0000000000) && (dut.mul_do_type == 6'b000100)) || (diff_mul > 0.01))) begin
        $display("A = %5.15f", a_);
        $display("B = %5.15f", b_);

        if (((diff_mul_ < 0) && (diff_mul_ <= -LOWEST_SUBNORMAL_NUMBER)) || ((diff_mul_ > 0) && (diff_mul_ >= LOWEST_SUBNORMAL_NUMBER))) begin
          if (over) begin
            if ((foo > 0.0) && ((dut.mul_do != 16'b0_11111_0000000000) || (dut.mul_do_type != 6'b000100)))
              $finish;
            else if ((foo < 0.0) && ((dut.mul_do != 16'b1_11111_0000000000) || (dut.mul_do_type != 6'b000100)))
              $finish;
          end else
            $finish;
        end
      end
      @(negedge clk);
    end
  end

  initial begin
    repeat(ITER) begin
      while(dvo !== 1'b1)
        @(negedge clk);

      bar  = acc_q.pop_back();
      over_ = overflow_q_.pop_back();

      $display("Accumulation product (ideal):\t%5.15f", bar);
      $display("Accumulation product (real): \t%5.15f", float16_to_real_normal(dout));
      $display("Accumulation diff:\t\t\t\t%5.15f", bar - float16_to_real_normal(dout));
      diff_acc = abs_float((bar - float16_to_real_normal(dout)))/abs_float(bar);
      diff_acc_ = bar - float16_to_real_normal(dout);

      $display("\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tAccumulation diff (percentage):\t\t%5.15f", diff_acc);
      $display("\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tTime: %t", $time());
                                                                                                                                                                  /* BULLSHIT RIGHT HERE */
      if (((bar > 0.0) && (bar >  65504.0) && (dout[14:0] != 15'b11111_0000000000)) || ((bar < 0.0) && (bar < -65504.0) && (dout[14:0] != 15'b11111_0000000000)) || (diff_acc > 0.05)) begin
        $display("A = %5.15f", a_);
        $display("B = %5.15f", b_);

        if (((diff_acc_ < 0) && (diff_acc_ <= -LOWEST_SUBNORMAL_NUMBER)) || ((diff_acc_ > 0) && (diff_acc_ >= LOWEST_SUBNORMAL_NUMBER)))
          if (!over_)
            $finish;
      end
      @(negedge clk);
    end
    $display("[END OF TEST]");
    $finish;
  end

endmodule