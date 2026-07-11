`timescale 1ns / 1ps

module parameterized_adder 
import mx_pkg::*;
#(
    parameter int EXP_WIDTH  = 8,
    parameter int MANT_WIDTH = 7
)(
    input  logic [15:0] a,
    input  logic [15:0] b,
    output logic [15:0] sum
);

    // Local aliases mapping back to standard structural layouts
    bf16_t op_a, op_b, op_res;
    assign op_a = bf16_t'(a);
    assign op_b = bf16_t'(b);
    assign sum  = logic_vector_pack(op_res);

    // Helper function to cast structural representations cleanly back to logic arrays
    function automatic logic [15:0] logic_vector_pack(bf16_t in_struct);
        return {in_struct.sign, in_struct.exp, in_struct.mant};
    endfunction

    // Structural signals for the datapath
    logic signed [8:0] exp_diff;
    bf16_t max_op, min_op;
    
    // Internal extended mantissas to track hidden bit, guard, round, and sticky bits
    localparam int EXT_MANT_WIDTH = 1 + MANT_WIDTH + 3; 
    
    logic [EXT_MANT_WIDTH-1:0] max_mant;
    logic [EXT_MANT_WIDTH-1:0] min_mant;
    logic [EXT_MANT_WIDTH-1:0] min_mant_shifted;

    // --- MOVED DECLARATIONS TO MODULE SCOPE TO FIX VERILATOR ERRORS ---
    logic eff_sub;
    logic [EXT_MANT_WIDTH:0] sum_mant_ext; 
    logic [7:0]  final_exp;
    logic [EXT_MANT_WIDTH:0] norm_mant;
    logic [3:0]  lzc; 

    always_comb begin
        // ---------------------------------------------------------------------
        // 1. OPERAND SORTING & EXPONENT ALIGNMENT
        // ---------------------------------------------------------------------
        exp_diff = $signed({1'b0, op_a.exp}) - $signed({1'b0, op_b.exp});

        if (exp_diff >= 0) begin
            max_op   = op_a;
            min_op   = op_b;
        end else begin
            max_op   = op_b;
            min_op   = op_a;
            exp_diff = -exp_diff;
        end

        // Extract mantissas and append hidden bits (handle zero operands)
        max_mant = (max_op.exp == '0) ? '0 : {1'b1, max_op.mant, 3'b000};
        min_mant = (min_op.exp == '0) ? '0 : {1'b1, min_op.mant, 3'b000};

        // Align smaller operand's mantissa with dynamic sticky-bit retention
        if (exp_diff >= EXT_MANT_WIDTH) begin
            min_mant_shifted = '0;
            if (min_mant != '0) min_mant_shifted[0] = 1'b1; 
        end else begin
            logic [EXT_MANT_WIDTH-1:0] lost_bits;
            lost_bits = min_mant << (EXT_MANT_WIDTH - exp_diff);
            min_mant_shifted = min_mant >> exp_diff;
            if (lost_bits != '0) min_mant_shifted[0] = 1'b1;
        end

        // ---------------------------------------------------------------------
        // 2. EFFECTIVE OPERATION & ADDITION/SUBTRACTION
        // ---------------------------------------------------------------------
        eff_sub = max_op.sign ^ min_op.sign;

        if (eff_sub) begin
            sum_mant_ext = {1'b0, max_mant} - {1'b0, min_mant_shifted};
        end else begin
            sum_mant_ext = {1'b0, max_mant} + {1'b0, min_mant_shifted};
        end

        // ---------------------------------------------------------------------
        // 3. NORMALIZATION
        // ---------------------------------------------------------------------
        final_exp = max_op.exp;
        norm_mant = sum_mant_ext;

        if (sum_mant_ext == '0) begin
            op_res = '0; 
        end 
        else if (eff_sub == 1'b0 && sum_mant_ext[EXT_MANT_WIDTH]) begin
            norm_mant = sum_mant_ext >> 1;
            norm_mant[0] = norm_mant[0] | sum_mant_ext[0]; 
            final_exp = final_exp + 1'b1;
        end 
        else if (eff_sub == 1'b1 && !sum_mant_ext[EXT_MANT_WIDTH-1]) begin
            if      (sum_mant_ext[10]) lzc = 4'd0;
            else if (sum_mant_ext[9])  lzc = 4'd1;
            else if (sum_mant_ext[8])  lzc = 4'd2;
            else if (sum_mant_ext[7])  lzc = 4'd3;
            else if (sum_mant_ext[6])  lzc = 4'd4;
            else if (sum_mant_ext[5])  lzc = 4'd5;
            else if (sum_mant_ext[4])  lzc = 4'd6;
            else if (sum_mant_ext[3])  lzc = 4'd7;
            else if (sum_mant_ext[2])  lzc = 4'd8;
            else if (sum_mant_ext[1])  lzc = 4'd9;
            else                       lzc = 4'd10;

            if (final_exp > {4'b0, lzc}) begin
                norm_mant = sum_mant_ext << lzc;
                final_exp = final_exp - {4'b0, lzc};
            end else begin
                norm_mant = sum_mant_ext << (final_exp - 1);
                final_exp = 8'h0;
            end
        end

        // ---------------------------------------------------------------------
        // 4. ROUNDING & PACKING
        // ---------------------------------------------------------------------
        if (sum_mant_ext != '0) begin
            logic [6:0] r_mant;
            logic       g, r, s, round_up;

            r_mant = norm_mant[10:4]; 
            g      = norm_mant[3];    
            r      = norm_mant[2];    
            s      = |norm_mant[1:0]; 

            round_up = g && (r || s || r_mant[0]);

            op_res.sign = max_op.sign;

            if (round_up) begin
                if (r_mant == 7'h7F) begin
                    op_res.mant = '0;
                    op_res.exp  = final_exp + 1'b1;
                end else begin
                    op_res.mant = r_mant + 1'b1;
                    op_res.exp  = final_exp;
                end
            end else begin
                op_res.mant = r_mant;
                op_res.exp  = final_exp;
            end

            if (final_exp >= 8'hFF) begin
                op_res.exp  = 8'hFF;
                op_res.mant = '0;
            end
        end
    end

endmodule
