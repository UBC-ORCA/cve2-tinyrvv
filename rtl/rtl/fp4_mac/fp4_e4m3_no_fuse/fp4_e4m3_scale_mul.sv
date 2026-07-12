


/*
    Note that NVFP8 (E4M3) *does not* encode
    infinities.
*/
module normalize_e4m3
import fp4_pkg::*;
#( parameter int OUTPUT_EXP_BITS = 8)
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
    output bf16_t PABC, // E7M8 (intermediate)
    output logic isNaN,
    output logic isZero
);

    // Declare the variables
    logic A_is_zero;
    logic A_is_nan;
    logic [2:0] A_mant_norm;
    logic [7:0] A_exp_norm;

    logic B_is_zero;
    logic B_is_nan;
    logic [2:0] B_mant_norm;
    logic [7:0] B_exp_norm;

    logic C_is_zero;
    logic C_sign;
    logic signed [15:0] C_absval;

    logic S_PAB;

    normalize_e4m3
    #(.OUTPUT_EXP_BITS(8)) normA8 (
        .e4m3(A8), 
        .normalized_mant(A_mant_norm), 
        .normalized_exp(A_exp_norm), 
        .is_zero(A_is_zero), 
        .is_nan(A_is_nan)
    );

    normalize_e4m3
    #(.OUTPUT_EXP_BITS(8)) normB8 (
        .e4m3(B8), 
        .normalized_mant(B_mant_norm), 
        .normalized_exp(B_exp_norm), 
        .is_zero(B_is_zero), 
        .is_nan(B_is_nan)
    );

    // temp variables for multiplication
    logic [22:0] TEMP_M_PABC;
    logic [15:0] TEMP_PABC;

    /* Leading zeroes count */
    logic [7:0] lzc;
    logic [22:0] shifted_m_pabc;
    logic [6:0] actual_m_pabc;
    logic [7:0] actual_exp_pabc;        

    assign PABC = TEMP_PABC;

    assign C_is_zero = q14_2_C_in == 'b0;
    assign C_sign = q14_2_C_in[15];
    assign C_absval = -q14_2_C_in;

    /* Integer multiplication */
    assign TEMP_M_PABC = C_absval[14:0] * {1'b1, A_mant_norm} * {1'b1, B_mant_norm}; 

    assign S_PAB = A8.sign ^ B8.sign ^ C_sign;

    /* 
        Detect leading 0 from the product, 
        then round.
     */
    always_comb begin
        logic [6:0] pre_round_mant;
        logic g, r, s;
        logic round_up;

        casez (TEMP_M_PABC)
            23'b1??????????????????????: lzc = 5'd0;
            23'b01?????????????????????: lzc = 5'd1;
            23'b001????????????????????: lzc = 5'd2;
            23'b0001???????????????????: lzc = 5'd3;
            23'b00001??????????????????: lzc = 5'd4;
            23'b000001?????????????????: lzc = 5'd5;
            23'b0000001????????????????: lzc = 5'd6;
            23'b00000001???????????????: lzc = 5'd7;
            23'b000000001??????????????: lzc = 5'd8;
            23'b0000000001?????????????: lzc = 5'd9;
            23'b00000000001????????????: lzc = 5'd10;
            23'b000000000001???????????: lzc = 5'd11;
            23'b0000000000001??????????: lzc = 5'd12;
            23'b00000000000001?????????: lzc = 5'd13;
            23'b000000000000001????????: lzc = 5'd14;
            23'b0000000000000001???????: lzc = 5'd15;
            23'b00000000000000001??????: lzc = 5'd16;
            23'b000000000000000001?????: lzc = 5'd17;
            23'b0000000000000000001????: lzc = 5'd18;
            23'b00000000000000000001???: lzc = 5'd19;
            23'b000000000000000000001??: lzc = 5'd20;
            23'b0000000000000000000001?: lzc = 5'd21;
            23'b00000000000000000000001: lzc = 5'd22;
            23'b00000000000000000000000: lzc = 5'd23;
            default:                     lzc = 5'd0; 
        endcase

        shifted_m_pabc = TEMP_M_PABC << lzc;
        pre_round_mant = shifted_m_pabc[21:15];
        g = shifted_m_pabc[13];
        r = shifted_m_pabc[12];
        s = |shifted_m_pabc[11:0];

        round_up = g & (r | s | pre_round_mant[0]);

        if (round_up) begin
            if (pre_round_mant == 7'h7F) begin
                // mantissa becomes 1.000000
                // exponent +1
                actual_m_pabc = 7'h0;
                actual_exp_pabc = A_exp_norm + B_exp_norm - 8'd1;
            end else begin
                actual_m_pabc = pre_round_mant + 7'd1;
                actual_exp_pabc = A_exp_norm + B_exp_norm 
                                    - lzc - 8'd2; 
            end
        end else begin 
            actual_m_pabc = pre_round_mant;
            actual_exp_pabc = A_exp_norm + B_exp_norm - 8'd2 -lzc;
        end
    end

    // finalize the output
    assign TEMP_PABC = {S_PAB, actual_exp_pabc, actual_m_pabc};    

    assign isNaN = A_is_nan | B_is_nan;
    assign isZero = (A_is_zero | B_is_zero | C_is_zero) & !isNaN;

    // always_comb begin
    //     $display("MA_appended = %b, MB_appended = %b", MA_appended, MB_appended);
    //     $display("normalized_EA = %b, normalized_EB = %b", normalized_EA, normalized_EB);
    //     $display("S_PAB = %b, TEMP_E_PAB = %b, TEMP_M_PAB = %b", S_PAB, TEMP_E_PAB, TEMP_M_PAB);
    //     $display("TEMP_PAB = %b", TEMP_PAB);
    // end
    
endmodule
