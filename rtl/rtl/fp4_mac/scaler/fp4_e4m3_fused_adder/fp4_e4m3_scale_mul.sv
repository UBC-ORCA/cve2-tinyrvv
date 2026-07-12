
// TEMP
typedef struct packed {
    logic sign; 
    logic [3:0] exp;
    logic [2:0] mant;
} fp4_scaler_e4m3_t;


/*
    Note that NVFP8 (E4M3) *does not* encode
    infinities.
*/
module normalize_e4m3
#( parameter int OUTPUT_EXP_BITS = 5)
 (
    input fp4_scaler_e4m3_t e4m3,
    output logic [2:0] normalized_mant,
    output logic [OUTPUT_EXP_BITS-1:0] normalized_exp, 
    output logic is_subnormal, 
    output logic is_zero,
    output logic is_nan
);

    localparam logic [OUTPUT_EXP_BITS-1:0] E4M3_BIAS = 'd8;
    localparam logic [OUTPUT_EXP_BITS-1:0] OUT_BIAS = (1 << (OUTPUT_EXP_BITS - 1)) - 1;
    logic [3:0] sub_shift_l;

    assign is_zero = e4m3[6:0] == 'b0;
    assign is_subnormal = (e4m3.exp == 'b0) && (!is_zero);
    assign is_nan = &e4m3[6:0];
    always_comb begin
        sub_shift_l = 4'd0;

        if (is_subnormal) begin
            /* Shift back mantissa to correct place */
            casez (e4m3.mant)
                3'b1??: sub_shift_l = 4'd1; 
                3'b01?: sub_shift_l = 4'd2;
                3'b001: sub_shift_l = 4'd3;
                default: begin // 3'b000
                    assert (is_zero)
                    else $error("Mantissa is zero but reached this statement"); 
                    sub_shift_l = 4'd0;
                end
            endcase

            normalized_mant = e4m3.mant << sub_shift_l;
            normalized_exp = OUT_BIAS + 1'b1 - E4M3_BIAS - sub_shift_l;
        end else begin 
            normalized_mant = e4m3.mant;
            normalized_exp = e4m3.exp + OUT_BIAS - E4M3_BIAS; 
        end
    end
endmodule


module e4m3_mul
import fp4_pkg::*; (
    input fp4_scaler_e4m3_t A8,
    input fp4_scaler_e4m3_t B8,
    input logic signed [15:0] q14_2_C_in,
    output logic [28:0] PAB, // E5M23 
    output logic isNaN,
    output logic isZero
);

    // Declare the variables
    logic A_is_subnormal;
    logic A_is_zero;
    logic A_is_nan;
    logic [2:0] A_mant_norm;
    logic [4:0] A_exp_norm;

    logic B_is_subnormal;
    logic B_is_zero;
    logic B_is_nan;
    logic [2:0] B_mant_norm;
    logic [4:0] B_exp_norm;

    logic C_is_zero;
    logic C_sign;
    logic signed [15:0] C_absval;

    logic S_PABC;
    logic [22:0] M_PABC; 
    logic [4:0] E_PAB;

    normalize_e4m3 #(.OUTPUT_EXP_BITS(5)) normA8 (
        .e4m3(A8), 
        .normalized_mant(A_mant_norm), 
        .normalized_exp(A_exp_norm), 
        .is_subnormal(A_is_subnormal), 
        .is_zero(A_is_zero), 
        .is_nan(A_is_nan)
    );

    normalize_e4m3 normB8 (
        .e4m3(B8), 
        .normalized_mant(B_mant_norm), 
        .normalized_exp(B_exp_norm), 
        .is_subnormal(B_is_subnormal), 
        .is_zero(B_is_zero), 
        .is_nan(B_is_nan)
    );

    /* Muliply */   

    assign C_is_zero = q14_2_C_in == 'b0;
    assign C_sign = q14_2_C_in[15];
    assign C_absval = -q14_2_C_in;


    assign M_PABC = {1'b1, A_mant_norm} * {1'b1, B_mant_norm} 
                    * {C_absval[14:0]};

    assign E_PAB = A_exp_norm + B_exp_norm; // actual exponent
    assign S_PABC = A8.sign ^ B8.sign ^ C_sign;

    // finalize the output
    assign PAB = {S_PABC, E_PAB, M_PABC};    

    assign isNaN = A_is_nan | B_is_nan;
    assign isZero = (A_is_zero | B_is_zero | C_is_zero) & !isNaN;

    // always_comb begin
    //     $display("MA_appended = %b, MB_appended = %b", MA_appended, MB_appended);
    //     $display("normalized_EA = %b, normalized_EB = %b", normalized_EA, normalized_EB);
    //     $display("S_PAB = %b, TEMP_E_PAB = %b, TEMP_M_PAB = %b", S_PAB, TEMP_E_PAB, TEMP_M_PAB);
    //     $display("TEMP_PAB = %b", TEMP_PAB);
    // end
    
endmodule
