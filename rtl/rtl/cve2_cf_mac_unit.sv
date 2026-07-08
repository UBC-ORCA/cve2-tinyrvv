`timescale 1ns/1ps
/******************************************************************************
 *
 * cve2_cf_mac_unit.sv
 *
 * Wrapper between the CVE2 custom-function interface and the MAC array.
 *
 * Responsibilities
 *   - Parse packed FP4 operands from rs1/rs2
 *   - Instantiate MAC controller
 *   - Instantiate MAC array
 *   - Connect controller outputs to MAC array inputs
 *
 ******************************************************************************/

module cve2_cf_mac_unit
(
    input  logic                     clk_i,
    input  logic                     rst_ni,

    //------------------------------------------------------------
    // CVE2 request interface
    //------------------------------------------------------------

    input  logic                     req_valid_i,
    input  cve2_pkg::mac_op_e        cf_req_op_i,

    input  logic [31:0]              req_instr_i,
    input  logic [31:0]              req_rs1_i,
    input  logic [31:0]              req_rs2_i,

    //------------------------------------------------------------
    // Status
    //------------------------------------------------------------

    output logic                     req_ready_o,
    output logic                     busy_o,
    output logic                     done_o
);

    localparam int TT = 8;

    //------------------------------------------------------------
    // Controller -> MAC array
    //------------------------------------------------------------

    logic mac_en;
    logic clear;

    //------------------------------------------------------------
    // Unpacked FP4 vectors
    //------------------------------------------------------------

    logic [3:0] act_vector [0:TT-1];
    logic [3:0] weight_vector [0:TT-1];

    //------------------------------------------------------------
    // MAC accumulator tile
    //------------------------------------------------------------

    logic signed [15:0] tile_accum [0:TT-1][0:TT-1];

    //------------------------------------------------------------
    // Parse packed FP4 operands
    //
    // rs1 = 8 activations
    // rs2 = 8 weights
    //------------------------------------------------------------

    genvar i;

    generate

        for (i = 0; i < TT; i++) begin : GEN_UNPACK

            assign act_vector[i]    = req_rs1_i[4*i +: 4];
            assign weight_vector[i] = req_rs2_i[4*i +: 4];

        end

    endgenerate

    //------------------------------------------------------------
    // MAC controller
    //------------------------------------------------------------

    mac_controller u_ctrl
    (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .req_valid_i(req_valid_i),
        .cf_req_op_i(cf_req_op_i),

        .rs1_i(req_rs1_i),
        .rs2_i(req_rs2_i),

        .mac_en_o(mac_en),
        .clear_o(clear),

        .req_ready_o(req_ready_o),
        .busy_o(busy_o),
        .done_o(done_o)
    );

    //------------------------------------------------------------
    // MAC array
    //------------------------------------------------------------

    mac_array
    #(
        .TT(TT)
    )
    u_array
    (
        .clk(clk_i),
        .rst_n(rst_ni),

        .mac_en_i(mac_en),
        .clear_i(clear),

        .act_i(act_vector),
        .wt_i(weight_vector),

        .accum_o(tile_accum)
    );

endmodule
