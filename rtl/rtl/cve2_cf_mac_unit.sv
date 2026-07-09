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

// --- [stev] --- unused signals
   output logic                     scalar_we_o,
    output logic [4:0]               scalar_waddr_o,
    output logic [31:0]              scalar_wdata_o,

    output logic                     data_req_o,
    input  logic                     data_gnt_i,
    output logic [31:0]              data_addr_o,
    output logic                     data_we_o,
    output logic [3:0]               data_be_o,
    output logic [31:0]              data_wdata_o,

    input  logic [31:0]              data_rdata_i,
    input  logic                     data_rvalid_i,
    input  logic                     data_err_i,

// --- [end] ---



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
    output logic                     done_o,

// --- [stev] ---
output logic [4:0] mac_vrf_raddr_o,
output  logic [2:0]   mac_vrf_relem_o,
input logic [31:0]   mac_vrf_rdata_i

// Weight memory interface
//output logic [31:0] weight_addr_o


// --- [end] ---
);


// --- [stev] ---
    //------------------------------------------------------------
    // Decoded VMAC instruction fields
    //------------------------------------------------------------

    // Temporary VMAC encoding:
    // [11:7]   = vs1 (vector source register)
    // [24:20]  = weight block index
    // req_rs1_i = base pointer
//TO BE RM
    logic [4:0] vs1;
    logic [4:0] weight_blk;
    logic [31:0] weight_base;

    assign vs1        = req_instr_i[11:7];
    assign weight_blk = req_instr_i[24:20];
    assign weight_base = req_rs1_i;

// --- [end] ---

// --- [stev] ---
//------------------------------------------------------------
// Controller -> Memory interface
//------------------------------------------------------------

logic        mem_req;
logic [31:0] mem_addr;
logic        mem_we;
logic [3:0]  mem_be;
logic [31:0] mem_wdata;

assign data_req_o   = mem_req;
assign data_addr_o  = mem_addr;
assign data_we_o    = mem_we;
assign data_be_o    = mem_be;
assign data_wdata_o = mem_wdata;
// --- [end] ---


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

// --- [stev] ---
//TEMP 
// New decoded VMAC fields
        .vs1_i        (vs1),
        .weight_blk_i (weight_blk),
        .base_i       (weight_base),

.mac_vrf_raddr_o(mac_vrf_raddr_o),
.mac_vrf_relem_o(mac_vrf_relem_o),

// [stev] - load weight
.data_req_o   (mem_req),
.data_gnt_i      (data_gnt_i),
.data_addr_o  (mem_addr),
.data_we_o    (mem_we),
.data_be_o    (mem_be),
.data_wdata_o (mem_wdata),

// Weight memory response
.data_rvalid_i   (data_rvalid_i),
.data_rdata_i    (data_rdata_i), //[stev] - may not need to pass into controller
.data_err_i      (data_err_i),

// --- [end] ---

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

// --- [stev] ---
//------------------------------------------------------------
// Debug: MAC VRF read port
//------------------------------------------------------------
//`ifdef VEC_DEBUG
always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        $display("[MAC_VRF] addr=v%0d elem=%0d data=%08x",
                 mac_vrf_raddr_o,
                 mac_vrf_relem_o,
                 mac_vrf_rdata_i);
    end
end
//`endif

//`ifdef VEC_DEBUG
always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        $display("[%0t] [MAC_VRF] raddr=v%0d relem=%0d rdata=%08x mac_en=%0b busy=%0b done=%0b",
                 $time,
                 mac_vrf_raddr_o,
                 mac_vrf_relem_o,
                 mac_vrf_rdata_i,
                 mac_en,
                 busy_o,
                 done_o);
    end
end
//`endif

always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        $display("[%0t] [MAC_MEM] req=%0b gnt=%0b addr=%08x we=%0b be=%0h wdata=%08x rvalid=%0b rdata=%08x err=%0b busy=%0b done=%0b mac_en=%0b",
                 $time,
                 data_req_o,
                 data_gnt_i,
                 data_addr_o,
                 data_we_o,
                 data_be_o,
                 data_wdata_o,
                 data_rvalid_i,
                 data_rdata_i,
                 data_err_i,
                 busy_o,
                 done_o,
                 mac_en);
    end
end


// --- [end] ---

endmodule
