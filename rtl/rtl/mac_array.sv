`timescale 1ns/1ps
/******************************************************************************
 * mac_array.sv
 *
 * TT × TT array of FP4 MAC cells.
 *
 * Responsibilities:
 *   - Distribute one activation vector across rows.
 *   - Distribute one weight vector across columns.
 *   - Instantiate TT×TT identical MAC cells.
 *   - Expose the accumulator state of every MAC.
 *
 * This module is intentionally ISA-independent.
 ******************************************************************************/

module mac_array #(

    parameter int TT = 8

)(

    input logic clk,
    input logic rst_n,

    //----------------------------------------------------------
    // Global control
    //----------------------------------------------------------

    input logic mac_en_i,
    input logic clear_i,

    //----------------------------------------------------------
    // One FP4 activation per row
    //----------------------------------------------------------

    input logic [3:0] act_i [0:TT-1],

    //----------------------------------------------------------
    // One FP4 weight per column
    //----------------------------------------------------------

    input logic [3:0] wt_i [0:TT-1],

    //----------------------------------------------------------
    // Full accumulator tile
    //----------------------------------------------------------

    output logic signed [15:0] accum_o [0:TT-1][0:TT-1]

);

    //----------------------------------------------------------
    // Instantiate TT × TT MAC cells
    //----------------------------------------------------------

    genvar r, c;

    generate

        for (r = 0; r < TT; r++) begin : GEN_ROW

            for (c = 0; c < TT; c++) begin : GEN_COL

                mac_cell u_mac (

                    .clk      (clk),
                    .rst_n    (rst_n),

                    .mac_en_i (mac_en_i),
                    .clear_i  (clear_i),

                    .act_i    (act_i[r]),
                    .wt_i     (wt_i[c]),

                    .accum_o  (accum_o[r][c])

                );

            end

        end

    endgenerate

endmodule
