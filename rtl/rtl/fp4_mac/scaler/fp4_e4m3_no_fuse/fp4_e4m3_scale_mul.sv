`timescale 1ns / 1ps


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
    
    /* Encodes *the actual* value (unbiased)*/
    output logic signed [OUTPUT_EXP_BITS-1:0] normalized_exp, 
    output logic is_zero,
    output logic is_subnormal,
    output logic is_nan
);

    localparam logic [OUTPUT_EXP_BITS-1:0] E4M3_BIAS = 'd7;
    localparam logic [OUTPUT_EXP_BITS-1:0] OUT_BIAS = (1 << (OUTPUT_EXP_BITS - 1)) - 1;
    logic [3:0] sub_shift_l;
    // logic is_subnormal;

    assign is_zero = e4m3[6:0] == 'b0;
    assign is_subnormal = (e4m3.exp == 'b0) && (!is_zero);
    assign is_nan = &e4m3[6:0];
    always_comb begin
        sub_shift_l = 4'd0;

        if (is_subnormal) begin
            /* Shift back mantissa to correct place */
            unique casez (e4m3.mant)
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
            normalized_exp = 1'b1 - E4M3_BIAS - sub_shift_l;
        end else begin 
            normalized_mant = e4m3.mant;
            normalized_exp = e4m3.exp - E4M3_BIAS; 
        end
    end

    always_comb begin
        if (is_subnormal) begin
            
        end
    end

endmodule


module e4m3_mul
import fp4_pkg::*; (
    input fp4_scaler_e4m3_t A8,
    input fp4_scaler_e4m3_t B8,
    input logic signed [15:0] q14_2_C_in,
    output bf16_t PABC, // E8M7 (intermediate)
    output logic isNaN,
    output logic isZero
);

    localparam logic [14:0] BF16_NAN = 15'h7fc0;

    // Declare the variables
    logic A_is_zero;
    logic A_is_nan;
    logic A_is_subnormal;
    logic [2:0] A_mant_norm;
    logic signed [7:0] A_exp_norm;

    logic B_is_zero;
    logic B_is_nan;
    logic B_is_subnormal;
    logic [2:0] B_mant_norm;
    logic signed [7:0] B_exp_norm;

    logic C_is_zero;
    logic C_sign;

    /* 1 extra bit to account for the sign */
    logic signed [16:0] C_absval;

    logic S_PAB;

    normalize_e4m3
    #(.OUTPUT_EXP_BITS(8)) normA8 (
        .e4m3(A8), 
        .normalized_mant(A_mant_norm), 
        .normalized_exp(A_exp_norm), 
        .is_zero(A_is_zero), 
        .is_nan(A_is_nan), 
        .is_subnormal(A_is_subnormal)
    );

    normalize_e4m3
    #(.OUTPUT_EXP_BITS(8)) normB8 (
        .e4m3(B8), 
        .normalized_mant(B_mant_norm), 
        .normalized_exp(B_exp_norm), 
        .is_zero(B_is_zero), 
        .is_nan(B_is_nan), 
        .is_subnormal(B_is_subnormal)
    );

    // temp variables for multiplication
    logic [22:0] TEMP_M_PABC;
    logic [14:0] TEMP_PABC;

    /* Point Adjustment Signals */
    logic [7:0] lzc; // leading zeros count
    logic [22:0] shifted_m_pabc;
    logic [6:0] pre_round_mant;
    logic signed [7:0] exp_shift_amount;

    /* ROUNDING SIGNALS */
    /* Guard, Round and Sticky bits */
    logic g, r, s;
    logic round_up;

    /* Final Values */
    logic [6:0] actual_m_pabc;
    logic [7:0] actual_exp_pabc;        

    assign C_is_zero = q14_2_C_in == 'b0;
    assign C_sign = q14_2_C_in[15];
    assign C_absval = C_sign ? -q14_2_C_in : q14_2_C_in;

    /* Integer multiplication */
    assign TEMP_M_PABC = C_absval[14:0] * {1'b1, A_mant_norm} * {1'b1, B_mant_norm}; 

    assign S_PAB = A8.sign ^ B8.sign ^ C_sign;

    /* 
        Detect leading 0 from the product, 
        then round.
     */
    always_comb begin


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
        exp_shift_amount = 8'sd23 
                                - (8'd8) // original point (3 + 3 + 2)
                                - (lzc + 1);
        pre_round_mant = shifted_m_pabc[21:15];
        g = shifted_m_pabc[14];
        r = shifted_m_pabc[13];
        s = |shifted_m_pabc[12:0];

        round_up = g & (r | s | pre_round_mant[0]);

        if (round_up) begin
            if (pre_round_mant == 7'h7F) begin
                // mantissa becomes 1.000000
                // exponent +1
                actual_m_pabc = 7'h0;
                actual_exp_pabc = A_exp_norm + B_exp_norm + 8'h7F + 1'd1 
                                    + exp_shift_amount;
            end else begin
                actual_m_pabc = pre_round_mant + 7'd1;
                actual_exp_pabc = A_exp_norm + B_exp_norm 
                                    + exp_shift_amount + 8'h7F;
            end
        end else begin 
            actual_m_pabc = pre_round_mant;
            actual_exp_pabc = A_exp_norm + B_exp_norm 
                                + exp_shift_amount + 8'h7F;
        end
    end

    // finalize the output
    assign TEMP_PABC = {actual_exp_pabc, actual_m_pabc};    

    assign isNaN = A_is_nan | B_is_nan;
    assign isZero = (A_is_zero | B_is_zero | C_is_zero) & !isNaN;

    assign PABC =  {S_PAB, 
        isNaN ? BF16_NAN : (isZero ? 15'b0 : TEMP_PABC)
    };
    

    // `ifndef SYNTHESIS 
        // always_comb begin 
        //     $display("==============  MONITOR: MUL_UNIT ===============\n");
        //     $display("A_raw; 0b%08b (0x%02h), B_raw; 0b%08b (0x%02h), C_raw 0b%016b (%05d)\n", A8, A8, 
        //         B8, B8, q14_2_C_in, $signed(q14_2_C_in));
        //     $display("A: subnorm: 0x%02h, norm_mant 0b%03b, norm_exp 0b%3d\n", 
        //                 A_is_subnormal, A_mant_norm, A_exp_norm);
        //     $display("B: subnorm: 0x%02h, norm_mant 0b%03b, norm_exp 0b%3d\n", 
        //                 B_is_subnormal, B_mant_norm, B_exp_norm);
        //     $display("C: absval: 0x%04h\n", C_absval);
        //     $display("TEMP_M_PABC: 0x%023b, shifted_m_pabc: 0b%023b, pre_round_mant: 0b%07b, lzc: %d\n", 
        //                 TEMP_M_PABC, shifted_m_pabc, pre_round_mant, lzc);
        //     $display("exp_adjustment (shift_left): %d\n", $signed(exp_shift_amount));
        //     $display("OUTPUT: {s:0'b%b, e:0b%08b (%3d), m:0b%07b}, NaN: %b, Zero: %b\n", 
        //                 S_PAB, actual_exp_pabc, $signed(actual_exp_pabc - 'h7f), actual_m_pabc, isNaN, isZero);

        //     $display("===============================================\n");
        //     $display("\n");
        // end
    // `endif

    // always_comb begin
    //     $display("MA_appended = %b, MB_appended = %b", MA_appended, MB_appended);
    //     $display("normalized_EA = %b, normalized_EB = %b", normalized_EA, normalized_EB);
    //     $display("S_PAB = %b, TEMP_E_PAB = %b, TEMP_M_PAB = %b", S_PAB, TEMP_E_PAB, TEMP_M_PAB);
    //     $display("TEMP_PAB = %b", TEMP_PAB);
    // end
    
endmodule
