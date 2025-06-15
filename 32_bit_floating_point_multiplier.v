module fp_multiplier (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] product
);

    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [22:0] frac_a = a[22:0];
    wire [22:0] frac_b = b[22:0];

    wire a_is_zero = (exp_a == 8'd0) && (frac_a == 23'd0);
    wire b_is_zero = (exp_b == 8'd0) && (frac_b == 23'd0);
    wire is_nan_a = (exp_a == 8'hFF) && (frac_a != 0);
    wire is_nan_b = (exp_b == 8'hFF) && (frac_b != 0);
    wire is_inf_a = (exp_a == 8'hFF) && (frac_a == 0);
    wire is_inf_b = (exp_b == 8'hFF) && (frac_b == 0);

    wire sign = sign_a ^ sign_b;

   
    wire [23:0] mant_a = (exp_a == 0) ? {1'b0, frac_a} : {1'b1, frac_a}; //hidden 1 bit
    wire [23:0] mant_b = (exp_b == 0) ? {1'b0, frac_b} : {1'b1, frac_b}; //hidden 1 bit

    wire [47:0] mant_product = mant_a * mant_b;
    wire [8:0] exp_sum = (exp_a == 0 ? 8'd1 : exp_a) + (exp_b == 0 ? 8'd1 : exp_b) - 8'd127;

    reg [31:0] result;
    reg [47:0] normalized_mant;
    reg [8:0] exp_adjusted;
    reg guard, round_bit, sticky;
    reg round_up;
    reg [22:0] mant_round_pre;
    reg [23:0] mant_rounded;
    reg [22:0] final_frac;
    reg [7:0] final_exp;

    always @(*) begin
        if (is_nan_a || is_nan_b || (is_inf_a && b_is_zero) || (is_inf_b && a_is_zero)) begin
            // Result is canonical NaN
            result = 32'h7FC00000;
        end else if (is_inf_a || is_inf_b) begin
            // Result is infinity
            result = {sign, 8'hFF, 23'd0};
        end else if (a_is_zero || b_is_zero) begin
            // Result is zero
            result = {sign, 31'd0};
        end else begin
            if (mant_product[47]) begin
                normalized_mant = mant_product;
                exp_adjusted = exp_sum + 1;
            end else begin
                normalized_mant = mant_product << 1;
                exp_adjusted = exp_sum;
            end

            guard = normalized_mant[23];         // 1st bit after mantissa
            round_bit = normalized_mant[22];     // 2nd bit after mantissa
            sticky = |normalized_mant[21:0];     // OR of remaining bits

            mant_round_pre = normalized_mant[46:24];

    
            round_up = guard & (round_bit | sticky | mant_round_pre[0]);

            mant_rounded = {1'b0, mant_round_pre} + round_up;

    
            if (mant_rounded[23]) begin
                final_frac = mant_rounded[22:0];
                final_exp  = exp_adjusted + 1;
            end else begin
                final_frac = mant_rounded[22:0];
                final_exp  = exp_adjusted;
            end

            if (final_exp >= 8'hFF) begin
                // Overflow -> infinity
                result = {sign, 8'hFF, 23'd0};
            end else if (final_exp <= 0) begin
                // Underflow -> zero 
                result = {sign, 8'd0, 23'd0};
            end else begin
                result = {sign, final_exp[7:0], final_frac};
            end
        end
    end

    assign product = result;

endmodule
