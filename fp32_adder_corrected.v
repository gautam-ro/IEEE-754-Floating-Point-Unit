`timescale 1ns / 1ps

module fp32_adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result
);

    // Module-level variable declarations (Verilog 2001 style)
    integer i;

    // Bit field extraction
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [22:0] frac_a = a[22:0];
    wire [22:0] frac_b = b[22:0];

    // Special case detection (enhanced)
    wire a_nan = (exp_a == 8'hFF) && (frac_a != 0);
    wire b_nan = (exp_b == 8'hFF) && (frac_b != 0);
    wire a_inf = (exp_a == 8'hFF) && (frac_a == 0);
    wire b_inf = (exp_b == 8'hFF) && (frac_b == 0);
    wire a_zero = (exp_a == 8'd0) && (frac_a == 23'd0);
    wire b_zero = (exp_b == 8'd0) && (frac_b == 23'd0);

    // Enhanced special case handling
    wire [31:0] special_result = 
        a_nan         ? a :
        b_nan         ? b :
        (a_inf && b_inf && sign_a != sign_b) ? 32'h7FC00000 : // INF - INF = NaN
        a_inf         ? a :
        b_inf         ? b :
        (a_zero && b_zero) ? {(sign_a && sign_b), 31'd0} : // -0 + -0 = -0, else +0
        a_zero        ? b :
        b_zero        ? a :
        32'h00000000;

    wire is_special = a_nan || b_nan || a_inf || b_inf || (a_zero || b_zero);

    // Mantissa normalization for subnormals
    wire [24:0] norm_mant_a = (exp_a == 0) ? {2'b00, frac_a} : {2'b01, frac_a};
    wire [24:0] norm_mant_b = (exp_b == 0) ? {2'b00, frac_b} : {2'b01, frac_b};
    wire [7:0] exp_eff_a = (exp_a == 0) ? 8'd1 : exp_a;
    wire [7:0] exp_eff_b = (exp_b == 0) ? 8'd1 : exp_b;

    // Magnitude comparison and swapping
    wire swap = (exp_eff_b > exp_eff_a) || 
                (exp_eff_b == exp_eff_a && norm_mant_b > norm_mant_a);

    wire [24:0] mant_large = swap ? norm_mant_b : norm_mant_a;
    wire [24:0] mant_small = swap ? norm_mant_a : norm_mant_b;
    wire sign_large = swap ? sign_b : sign_a;
    wire sign_small = swap ? sign_a : sign_b;
    wire [7:0] exp_large = swap ? exp_eff_b : exp_eff_a;
    wire [7:0] exp_small = swap ? exp_eff_a : exp_eff_b;

    // Alignment
    wire [7:0] shift = (exp_large > exp_small) ? (exp_large - exp_small) : 8'd0;
    wire [27:0] aligned_small = {mant_small, 3'b000} >> (shift > 27 ? 27 : shift);
    wire [27:0] aligned_large = {mant_large, 3'b000};

    // Addition/Subtraction
    wire [27:0] sum = (sign_large == sign_small) ? 
                      (aligned_large + aligned_small) :
                      (aligned_large - aligned_small);

    wire result_sign = (sum == 0) ? 1'b0 : sign_large;

    // Verilog 2001 compliant leading zero detection function
    function [4:0] count_leading_zeros;
        input [27:0] value;
        integer j;
        begin
            count_leading_zeros = 5'd28;
            for (j = 27; j >= 0; j = j - 1) begin
                if (value[j]) begin
                    count_leading_zeros = 27 - j;
                    j = -1; // This is acceptable in function context
                end
            end
        end
    endfunction

    // Alternative case-based leading zero detection (more hardware efficient)
    function [4:0] count_leading_zeros_case;
        input [27:0] value;
        begin
            casez (value)
                28'b1???????????????????????????: count_leading_zeros_case = 5'd0;
                28'b01??????????????????????????: count_leading_zeros_case = 5'd1;
                28'b001?????????????????????????: count_leading_zeros_case = 5'd2;
                28'b0001????????????????????????: count_leading_zeros_case = 5'd3;
                28'b00001???????????????????????: count_leading_zeros_case = 5'd4;
                28'b000001??????????????????????: count_leading_zeros_case = 5'd5;
                28'b0000001?????????????????????: count_leading_zeros_case = 5'd6;
                28'b00000001????????????????????: count_leading_zeros_case = 5'd7;
                28'b000000001???????????????????: count_leading_zeros_case = 5'd8;
                28'b0000000001??????????????????: count_leading_zeros_case = 5'd9;
                28'b00000000001?????????????????: count_leading_zeros_case = 5'd10;
                28'b000000000001????????????????: count_leading_zeros_case = 5'd11;
                28'b0000000000001???????????????: count_leading_zeros_case = 5'd12;
                28'b00000000000001??????????????: count_leading_zeros_case = 5'd13;
                28'b000000000000001?????????????: count_leading_zeros_case = 5'd14;
                28'b0000000000000001????????????: count_leading_zeros_case = 5'd15;
                28'b00000000000000001???????????: count_leading_zeros_case = 5'd16;
                28'b000000000000000001??????????: count_leading_zeros_case = 5'd17;
                28'b0000000000000000001?????????: count_leading_zeros_case = 5'd18;
                28'b00000000000000000001????????: count_leading_zeros_case = 5'd19;
                28'b000000000000000000001???????: count_leading_zeros_case = 5'd20;
                28'b0000000000000000000001??????: count_leading_zeros_case = 5'd21;
                28'b00000000000000000000001?????: count_leading_zeros_case = 5'd22;
                28'b000000000000000000000001????: count_leading_zeros_case = 5'd23;
                28'b0000000000000000000000001???: count_leading_zeros_case = 5'd24;
                28'b00000000000000000000000001??: count_leading_zeros_case = 5'd25;
                28'b000000000000000000000000001?: count_leading_zeros_case = 5'd26;
                28'b0000000000000000000000000001: count_leading_zeros_case = 5'd27;
                default: count_leading_zeros_case = 5'd28;
            endcase
        end
    endfunction

    // Normalization - using the case-based function for better synthesis
    reg [4:0] leading_zeros;
    reg [27:0] norm_sum;
    reg [8:0] norm_exp; // 9-bit to handle underflow

    always @(*) begin
        leading_zeros = count_leading_zeros_case(sum);
        norm_sum = sum << leading_zeros;
        norm_exp = exp_large - leading_zeros;
    end

    // Rounding (Round to nearest, ties to even)
    wire guard  = norm_sum[3];
    wire round_bit  = norm_sum[2];
    wire sticky = |norm_sum[1:0];
    wire r_up = guard & (round_bit | sticky | norm_sum[4]);

    wire [23:0] rounded = norm_sum[26:3] + r_up;
    wire carry = rounded[23];

    wire [8:0] final_exp = norm_exp + carry;
    wire [22:0] final_frac = carry ? rounded[22:0] : rounded[22:0];

    // Result assembly with proper subnormal handling
    wire [31:0] normal_result;
    assign normal_result = 
        (final_exp >= 9'h0FF) ? {result_sign, 8'hFF, 23'b0} :  // Overflow to infinity
        (final_exp <= 9'h000) ? 
            // Subnormal result or underflow to zero
            (final_exp < -22) ? {result_sign, 8'd0, 23'b0} :    // Complete underflow
            {result_sign, 8'd0, final_frac >> (1 - final_exp)} : // Subnormal
        {result_sign, final_exp[7:0], final_frac};              // Normal

    assign result = is_special ? special_result : normal_result;

endmodule