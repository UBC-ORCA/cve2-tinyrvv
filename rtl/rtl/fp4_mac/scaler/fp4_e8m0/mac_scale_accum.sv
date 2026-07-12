`timescale 1ns / 1ps

module mac_scale_accum 
import mx_pkg::*;
(
    input  logic signed [15:0] tile_value,
    input  logic [7:0]         scaleA,
    input  logic [7:0]         scaleB,
    input  logic [15:0]        accumulator,
    output logic [15:0]        accumulator_out
);

    // Intermediate structured wiring signals
    bf16_t bf16_tile;
    bf16_t bf16_scaled;

    // 1. Convert Int16 Accumulator Matrix Output into standard BF16 format
    int16_to_bf16 u_convert (
        .int_in   (tile_value),
        .bf16_out (bf16_tile)
    );

    // 2. Adjust Exponents dynamically utilizing E8M0 elements
    e8m0_scale u_scale (
        .bf16_in  (bf16_tile),
        .scale_a  (scaleA),
        .scale_b  (scaleB),
        .bf16_out (bf16_scaled)
    );

    // 3. Accumulate with BRAM memory context lines
    bf16_accumulate u_add (
        .bf16_scaled     (bf16_scaled),
        .accumulator_in  (accumulator),
        .accumulator_out (accumulator_out)
    );

endmodule
