`timescale 1ns/1ps

module add_tb ();

    logic [ 5:0] a_type, b_type;
    logic [15:0] a, b;
    logic [15:0] p             ;
    logic        dvi     = 1'b0;
    logic        dvo           ;
    logic [ 5:0] do_type       ;

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

    add #(5) dut (
      .CLK    (clk),
      .RSTn   (rst),
      .DVI    (dvi),
      .DI_TYPE({b_type, a_type}),
      .DI     ({b, a}),
      .DVO    (dvo),
      .DO_TYPE(do_type),
      .DO     (p)
    );

    real q;
    real qwe;
    real zxc;

    real a_queue [$];
    real b_queue [$];
    real q_queue [$];

    initial
      forever
        #5 clk = ~clk;

    initial
      #13 rst = ~rst;

    initial begin
      #10;

      // for (int i = 0; i < 10'h3FF; i = (i << 1) + 1) begin
      //   $display("--------------------------------------------------------------------\"subnormal + subnormal -> normal\"");
      //   #90;
      //   a_type = 6'b010000;
      //   a[15:10] = 'b0;
      //   a[ 9: 0] = i;
      //   b_type = 6'b010000;
      //   b = 16'b0_00000_0000000001;
      //   #10;
      //   // $display("a = %5.15f", float16_to_real_normal(a));
      //   // $display("b = %5.15f", float16_to_real_normal(b));
      //   q = float16_to_real_normal(a) + float16_to_real_normal(b);

      //   if (q - float16_to_real_normal(p) > 0)
      //     $finish;

      //   $display("Expected value: %5.15f\tp = %5.15f", q, float16_to_real_normal(p));
      // end
      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b000001;
      a      <= 16'b0_00000_1100000000;
      b_type <= 6'b001000;
      b      <= 16'b1_11111_0000000000;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b001000;
      a      <= 16'b0_00000_0100000000;
      b_type <= 6'b000010;
      b      <= 16'b1_11111_0000000000;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b000100;
      a      <= 16'b0_00000_0000000000;
      b_type <= 6'b000100;
      b      <= 16'b1_11111_0000000000;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));


      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b001000;
      a      <= 16'b1_00000_0000000000;
      b_type <= 6'b001000;
      b      <= 16'b0_00000_0000000000;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b100000;
      a      <= 16'b1_11110_1111111111;
      b_type <= 6'b010000;
      b      <= 16'b1_00000_0000000001;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      // @(posedge clk);
      // dvi    <= 1'b1;
      // a_type <= 6'b100000;
      // a      <= 16'b1_01010_1010101010;
      // b_type <= 6'b100000;
      // b      <= 16'b0_10101_0101010101;

      // @(negedge clk);
      // a_queue.push_front(float16_to_real_normal(a));
      // b_queue.push_front(float16_to_real_normal(b));
      // q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b100000;
      a      <= 16'b1_00001_0000100001;
      b_type <= 6'b100000;
      b      <= 16'b0_00001_0000000001;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b010000;
      a      <= 16'b1_00000_0000100001;
      b_type <= 6'b010000;
      b      <= 16'b0_00000_0000100001;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b100000;
      a      <= 16'b1_11110_1111111111;
      b_type <= 6'b100000;
      b      <= 16'b0_11110_1111111111;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b010000;
      a      <= 16'b0_00000_0000100001;
      b_type <= 6'b010000;
      b      <= 16'b1_00000_0000100001;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b010000;
      a      <= 16'b0_00000_1111111111;
      b_type <= 6'b010000;
      b      <= 16'b0_00000_0000000001;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b100000;
      a      <= 16'b0_10001_0000000000;
      b_type <= 6'b100000;
      b      <= 16'b0_10011_0000000000;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b100000;
      a      <= 16'b0_11110_1111111111;
      b_type <= 6'b100000;
      b      <= 16'b0_01111_0000000000;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      // @(posedge clk);
      // dvi    <= 1'b1;
      // a_type <= 6'b100000;
      // a      <= 16'b0_10101_1010101010;
      // b_type <= 6'b100000;
      // b      <= 16'b0_01010_0101010101;

      // @(negedge clk);
      // a_queue.push_front(float16_to_real_normal(a));
      // b_queue.push_front(float16_to_real_normal(b));
      // q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b010000;
      a      <= 16'b0_00000_0000000001;
      b_type <= 6'b010000;
      b      <= 16'b1_00000_0000000111;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b100000;
      a      <= 16'b0_10100_0000000000;
      b_type <= 6'b100000;
      b      <= 16'b1_10100_0000000111;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi    <= 1'b1;
      a_type <= 6'b100000;
      a      <= 16'b1_01100_1100000000;
      b_type <= 6'b100000;
      b      <= 16'b0_10001_0011000111;

      @(negedge clk);
      a_queue.push_front(float16_to_real_normal(a));
      b_queue.push_front(float16_to_real_normal(b));
      q_queue.push_front(float16_to_real_normal(a) + float16_to_real_normal(b));

      @(posedge clk);
      dvi <= 1'b0;
    end

    initial begin
      @(posedge clk);
      repeat(15) begin
        while (dvo !== 1'b1)
          @(posedge clk);

        qwe = a_queue.pop_back();
        zxc = b_queue.pop_back();
        q = q_queue.pop_back();

        $display("--------------------------------------------------------------------\"?\"");
        $display("a = %5.15f", qwe);
        $display("b = %5.15f", zxc);
        $display("Expected value: %5.15f\tp = %5.15f", q, float16_to_real_normal(p));

        if ((q != float16_to_real_normal(p)) && (q < 65504) && (q > -65504))
          $finish;
        @(posedge clk);
      end
    end

endmodule