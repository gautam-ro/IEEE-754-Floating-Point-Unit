`timescale 1ns / 1ps

module fp_adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] sum
);

    wire sign_a, sign_b;
    wire [7:0] exp_a, exp_b;
    wire [22:0] frac_a, frac_b;
    
    wire a_zero, b_zero, a_inf, b_inf, a_nan, b_nan;

    wire [23:0] m_a, m_b;
    wire [7:0] e_a, e_b;

    wire swap;
    wire [7:0] exp_large, exp_small;
    wire [23:0] mant_large, mant_small;
    wire sign_large, sign_small;

    wire [7:0] exp_diff;
    wire [27:0] aligned_small, aligned_large;

    wire op_sub;
    wire [28:0] mant_sum_raw;
    wire add_overflow;

    wire result_sign;

    reg [4:0] lz;
    integer i;

    wire [27:0] norm_sum;
    wire [8:0] norm_exp;

    wire guard, round_bit, sticky, lsb, round_up;

    wire [23:0] rounded;
    wire carry;
    wire [8:0] exp_tmp;
    wire [7:0] final_exp;
    wire [22:0] final_frac;
    
    wire [4:0] denorm_shift;
    wire [23:0] denorm_mant;


    wire [31:0] special_result;
    wire is_special;

    assign sign_a = a[31];
    assign sign_b = b[31];
    assign exp_a  = a[30:23];
    assign exp_b  = b[30:23];
    assign frac_a = a[22:0];
    assign frac_b = b[22:0];

    assign a_zero = (exp_a == 0 && frac_a == 0);
    assign b_zero = (exp_b == 0 && frac_b == 0);
    assign a_inf  = (exp_a == 8'hFF && frac_a == 0);
    assign b_inf  = (exp_b == 8'hFF && frac_b == 0);
    assign a_nan  = (exp_a == 8'hFF && frac_a != 0);
    assign b_nan  = (exp_b == 8'hFF && frac_b != 0);

    assign m_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a};
    assign m_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b};
    assign e_a = (exp_a == 0) ? 8'd1 : exp_a;
    assign e_b = (exp_b == 0) ? 8'd1 : exp_b;

    assign swap        = (e_b > e_a) || ((e_b == e_a) && (m_b > m_a));
    assign exp_large   = swap ? e_b : e_a;
    assign exp_small   = swap ? e_a : e_b;
    assign mant_large  = swap ? m_b : m_a;
    assign mant_small  = swap ? m_a : m_b;
    assign sign_large  = swap ? sign_b : sign_a;
    assign sign_small  = swap ? sign_a : sign_b;

    assign exp_diff = exp_large - exp_small;
    assign aligned_small = (exp_diff > 27) ? 28'd0 : ({mant_small, 4'b0000} >> exp_diff);
    assign aligned_large = {mant_large, 4'b0000};

    assign op_sub = sign_large ^ sign_small;
    assign mant_sum_raw = op_sub ? ({1'b0, aligned_large} - {1'b0, aligned_small})
                                 : ({1'b0, aligned_large} + {1'b0, aligned_small});
    
    assign add_overflow = mant_sum_raw[28];

    assign result_sign = (mant_sum_raw == 0) ? 1'b0 : sign_large;

    always @(*) begin
        lz = 5'd28;
        for (i = 27; i >= 0; i = i - 1) begin
            if (mant_sum_raw[i] && lz == 28) begin
                lz = 27 - i;
            end
        end
    end

    assign norm_sum = add_overflow ? mant_sum_raw[27:0] >> 1 : mant_sum_raw[27:0] << lz;
    assign norm_exp = add_overflow ? exp_large + 1 : exp_large - lz;

    assign guard     = norm_sum[3];
    assign round_bit = norm_sum[2];
    assign sticky    = |norm_sum[1:0];
    assign lsb       = norm_sum[4];
    assign round_up  = guard & (lsb | round_bit | sticky);

    wire [24:0] rounded_with_carry = {1'b0, norm_sum[27:4]} + round_up;
    assign rounded = rounded_with_carry[23:0];
    assign carry = rounded_with_carry[24];
    assign exp_tmp = norm_exp + carry;

    assign final_exp = (mant_sum_raw == 0) ? 8'd0 :
                       (exp_tmp > 8'hFE) ? 8'hFF :
                       ($signed(exp_tmp) < 1) ? 8'd0 : exp_tmp[7:0];

    assign denorm_shift = ($signed(exp_tmp) < 1) ? (1 - $signed(exp_tmp)) : 5'd0;
    assign denorm_mant = rounded >> denorm_shift;
    
    assign final_frac = (final_exp == 8'd0) ? denorm_mant[22:0] : rounded[22:0];

    assign special_result =
        a_nan ? a :
        b_nan ? b :
        (a_inf && b_inf && (sign_a != sign_b)) ? 32'h7FC00000 : 
        a_inf ? a :
        b_inf ? b :
        a_zero ? b :
        b_zero ? a :
        32'd0;

    assign is_special = a_nan || b_nan || a_inf || b_inf || a_zero || b_zero;

    always @(*) begin
        if (is_special)
            sum = special_result;
        else if (final_exp == 8'hFF)
            sum = {result_sign, 8'hFF, 23'd0}; // Overflow to Infinity
        else if (mant_sum_raw == 0)
            sum = 32'd0; // Result is zero
        else
            sum = {result_sign, final_exp, final_frac};
    end

endmodule
