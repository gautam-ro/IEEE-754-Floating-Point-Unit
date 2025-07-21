`timescale 1ns / 1ps

module tb_fp_adder;

    reg  [31:0] a, b;
    wire [31:0] sum;

    fp_adder uut (
        .a(a),
        .b(b),
        .sum(sum)
    );

    task generate_random_normal(output reg [31:0] f);
        reg [7:0] exp;
        reg [22:0] frac;
        reg sign;
        begin
            sign = $random;
            exp  = $urandom_range(1, 254);  // exclude denormals, NaN, Inf
            frac = $random;
            f = {sign, exp, frac};
        end
    endtask

    task generate_random_special(output reg [31:0] f);
        reg [2:0] type;
        reg sign;
        reg [22:0] frac;
        begin
            sign = $random;
            type = $urandom_range(0, 5); // 0=zero, 1=inf, 2=NaN, 3=denormal, 4-5=normal

            case (type)
                0: f = {sign, 8'd0, 23'd0};                // Zero
                1: f = {sign, 8'hFF, 23'd0};               // Infinity
                2: f = {sign, 8'hFF, 23'h000123};          // NaN (quiet)
                3: f = {sign, 8'd0, $random};              // Denormal
                default: generate_random_normal(f);       // Normal
            endcase
        end
    endtask

    initial begin
        $display("Time\t\tA\t\t\tB\t\t\tSum");

        repeat(20) begin
            generate_random_special(a);
            generate_random_special(b);
            #10;
            $display("%0t\t%h\t%h\t%h", $time, a, b, sum);
        end

        $finish;
    end
endmodule


