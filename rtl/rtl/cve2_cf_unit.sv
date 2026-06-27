`timescale 1ns/1ps
/******************************************************************************
 * cve2_cf_unit.sv
 *
 * CVE2 Custom Function (CF) Unit
 *
 * ============================================================================
 * PURPOSE
 * ============================================================================
 *
 * This module is intentionally designed to be a THIN ADAPTER between the
 * CVE2 processor pipeline and the fp4_mac8x8_gen1 MAC tile.
 *
 * It does NOT implement any MAC arithmetic itself.
 *
 * Responsibilities:
 *
 *   • Accept requests from the ID stage
 *   • Translate the decoded MAC opcode into one-cycle control pulses
 *   • Route operands into the MAC tile
 *   • Route tile outputs back to the CPU
 *   • Translate tile memory accesses into LSU requests
 *   • Generate the basic ready/busy/done handshake
 *
 * The MAC tile itself contains all instruction-specific behavior.
 *
 * ============================================================================
 * INSTRUCTION OWNERSHIP
 * ============================================================================
 *
 * cve2_decoder
 *      ↓
 *  decodes instruction
 *      ↓
 *  produces:
 *
 *      cf_req_valid
 *      cf_req_op
 *      cf_req_instr
 *      cf_req_rs1
 *      cf_req_rs2
 *
 *      ↓
 *
 * cve2_cf_unit
 *
 *      ↓
 *
 * fp4_mac8x8_gen1
 *
 * The wrapper therefore NEVER re-decodes instruction opcodes.
 *
 ******************************************************************************/

// =============================================================================
// cve2_vec_unit.sv (FINAL: MAC DISPATCHER FRONTEND)
//
// supported inst:
// 1) zzMAC64 
// 2) maxMAC64 rs1
// 3) hwMAC64 rs1, rs2
// 4) addMAC64 rs1, rs2 
// 5) mvoMAC64 rd, rs1, rs2 
// 6) mveMAC64 rd, rs1, rs2 
// 7) mv2MAC64 rd, rs1, rs2 
// 8) ld2MAC64 rs2, IMM12(rs1) 
// 9) st2MAC64 rs2, IMM12(rs1) 
//
// =============================================================================

module cve2_cf_unit (

    //----------------------------------------------------------------------
    // Clock / Reset
    //----------------------------------------------------------------------

    input  logic                     clk_i,
    input  logic                     rst_ni,

    //----------------------------------------------------------------------
    // Request from ID stage
    //----------------------------------------------------------------------

    input  logic                     req_valid_i,

    //
    // Already decoded MAC opcode from cve2_decoder.
    //
    // This is the ONLY opcode used by this wrapper.
    //
    input  cve2_pkg::mac_op_e        cf_req_op_i,

    //
    // Original instruction.
    //
    // Used ONLY for extracting fields such as:
    //
    //   rd
    //   rs1 field (row index)
    //   rs2 field (pair index)
    //   immediates
    //
    // The opcode bits are NOT decoded here.
    //
    input  logic [31:0]              req_instr_i,

    //
    // Integer register operands.
    //
    input  logic [31:0]              req_rs1_i,
    input  logic [31:0]              req_rs2_i,

    //
    // Request accepted.
    //
    output logic                     req_ready_o,

    //----------------------------------------------------------------------
    // Status back to ID stage
    //----------------------------------------------------------------------

    output logic                     busy_o,
    output logic                     done_o,

    //----------------------------------------------------------------------
    // Integer register writeback
    //----------------------------------------------------------------------

    output logic                     scalar_we_o,
    output logic [4:0]               scalar_waddr_o,
    output logic [31:0]              scalar_wdata_o,

    //----------------------------------------------------------------------
    // LSU Interface
    //----------------------------------------------------------------------

    output logic                     data_req_o,
    input  logic                     data_gnt_i,

    output logic [31:0]              data_addr_o,

    output logic                     data_we_o,

    output logic [3:0]               data_be_o,

    output logic [31:0]              data_wdata_o,

    input  logic [31:0]              data_rdata_i,
    input  logic                     data_rvalid_i,
    input  logic                     data_err_i

);

    //======================================================================
    // Internal control signals driving fp4_mac8x8_gen1
    //======================================================================

    logic clear_i;

    logic mac_en_i;
    logic max_en_i;
    logic add_en_i;

    logic [2:0] add_row_i;

    logic mv_en_i;
    logic [1:0] mv_op_i;

    logic ld2_en_i;
    logic st2_en_i;

    //======================================================================
    // Instruction field extraction
    //======================================================================

    //
    // addMAC64
    //
    // rs1 field encodes destination tile row.
    //
    assign add_row_i = req_instr_i[19:15][2:0];

    //
    // Move instructions
    //
    // rs1 field selects tile row.
    //
    logic [4:0] mv_row;

    //
    // rs2 field selects tile pair.
    //
    logic [4:0] mv_pair;

    assign mv_row  = req_instr_i[19:15];
    assign mv_pair = req_instr_i[24:20];

    //======================================================================
    // Data signals between wrapper and MAC tile
    //======================================================================

    //
    // Returned by mve/mvo/mv2 instructions.
    //
    logic [31:0] mv_data;

    //
    // Returned by st2 instruction.
    //
    logic [31:0] st2_data;

    //======================================================================
    // Control Pulse Generator
    //======================================================================
    //
    // The MAC tile expects ONE-CYCLE enable pulses.
    //
    // Therefore:
    //
    //     decoded opcode
    //             +
    //       req_valid_i
    //
    // are translated into single-cycle enables.
    //
    // This module performs NO arithmetic.
    //
    //======================================================================

    always_comb begin

        //--------------------------------------------------------------
        // Default everything inactive.
        //--------------------------------------------------------------

        clear_i  = 1'b0;

        mac_en_i = 1'b0;
        max_en_i = 1'b0;
        add_en_i = 1'b0;

        mv_en_i  = 1'b0;
        mv_op_i  = 2'd0;

        ld2_en_i = 1'b0;
        st2_en_i = 1'b0;

        //--------------------------------------------------------------
        // Dispatch
        //--------------------------------------------------------------

        unique case (cf_req_op_i)

            cve2_pkg::OP_ZZ : begin
                clear_i = req_valid_i;
            end

            cve2_pkg::OP_MAX : begin
                max_en_i = req_valid_i;
            end

            cve2_pkg::OP_MAC : begin
                mac_en_i = req_valid_i;
            end

            cve2_pkg::OP_ADD : begin
                add_en_i = req_valid_i;
            end

            cve2_pkg::OP_MVE : begin
                mv_en_i = req_valid_i;
                mv_op_i = 2'd0;
            end

            cve2_pkg::OP_MVO : begin
                mv_en_i = req_valid_i;
                mv_op_i = 2'd1;
            end

            cve2_pkg::OP_MV2 : begin
                mv_en_i = req_valid_i;
                mv_op_i = 2'd2;
            end

            cve2_pkg::OP_LD2 : begin
                ld2_en_i = req_valid_i;
            end

            cve2_pkg::OP_ST2 : begin
                st2_en_i = req_valid_i;
            end

            default : begin
            end

        endcase

    end


    //======================================================================
    // fp4_mac8x8_gen1
    //======================================================================
    //
    // The MAC tile owns ALL architectural state associated with the
    // accelerator.
    //
    // Specifically, it owns:
    //
    //   • 8x8 INT16 accumulation tile
    //   • FP4 unpacking
    //   • FP4 decode
    //   • Outer-product MAC datapath
    //   • maxMAC64
    //   • addMAC64
    //   • Move instructions
    //   • Tile load/store operations
    //
    // This wrapper simply routes requests into the tile.
    //
    //======================================================================

    fp4_mac8x8_gen1 u_mac (

        //------------------------------------------------------------------
        // Clock / Reset
        //------------------------------------------------------------------

        .clk            (clk_i),
        .rst_n          (rst_ni),

        //------------------------------------------------------------------
        // Tile control
        //------------------------------------------------------------------

        //
        // Exactly one of these enable signals should pulse for one cycle
        // for each dispatched MAC instruction.
        //

        .clear_i        (clear_i),

        .mac_en_i       (mac_en_i),
        .max_en_i       (max_en_i),

        .add_en_i       (add_en_i),
        .add_row_i      (add_row_i),

        //------------------------------------------------------------------
        // Packed FP4 operands
        //------------------------------------------------------------------
        //
        // rs1 and rs2 are already read from the integer register file by
        // the CVE2 pipeline.
        //
        // The MAC tile interprets these registers as packed FP4 vectors.
        //

        .a_packed_i     (req_rs1_i),
        .b_packed_i     (req_rs2_i),

        //------------------------------------------------------------------
        // Move instructions
        //------------------------------------------------------------------
        //
        // mveMAC64
        // mvoMAC64
        // mv2MAC64
        //
        // The instruction fields specify:
        //
        //   rs1 field -> tile row
        //   rs2 field -> tile pair
        //
        // The selected tile value(s) are returned on mv_data_o.
        //

        .mv_en_i        (mv_en_i),

        .mv_op_i        (mv_op_i),

        .mv_row_i       (mv_row),

        .mv_pair_i      (mv_pair),

        .mv_data_o      (mv_data),

        //------------------------------------------------------------------
        // Generic tile read interface
        //------------------------------------------------------------------
        //
        // The current ISA never uses the generic tile read interface.
        //
        // It is therefore permanently disabled.
        //
        // The interface is intentionally left connected so future revisions
        // can expose it without modifying the tile.
        //

        .rd_en_i        (1'b0),

        .rd_addr_i      ('0),

        .rd_data_o      (),

        //------------------------------------------------------------------
        // Tile memory operations
        //------------------------------------------------------------------
        //
        // ld2MAC64
        //
        //     Memory
        //         ↓
        //   data_rdata_i
        //         ↓
        //    ld2_data_i
        //         ↓
        //       Tile
        //
        //
        // st2MAC64
        //
        //      Tile
        //        ↓
        //   st2_data_o
        //        ↓
        // Wrapper
        //        ↓
        // data_wdata_o
        //        ↓
        //      LSU
        //

        .ld2_en_i       (ld2_en_i),

        .st2_en_i       (st2_en_i),

        .tile_mem_rs2_i (req_instr_i[24:20]),

        .ld2_data_i     (data_rdata_i),

        .st2_data_o     (st2_data)

    );

    //======================================================================
    // Integer Register Writeback
    //======================================================================
    //
    // Only move instructions write back into the integer register file.
    //
    //     mveMAC64
    //     mvoMAC64
    //     mv2MAC64
    //
    // The tile already produces the correctly formatted 32-bit value.
    //
    //======================================================================

    assign scalar_we_o =
           (cf_req_op_i == MAC_MVE) ||
           (cf_req_op_i == MAC_MVO) ||
           (cf_req_op_i == MAC_MV2);

    //
    // Destination register comes directly from the original instruction.
    //
    assign scalar_waddr_o = req_instr_i[11:7];

    //
    // Forward tile output directly.
    //
    assign scalar_wdata_o = mv_data;

    //======================================================================
    // LSU Interface
    //======================================================================
    //
    // Only two instructions interact with memory:
    //
    //      ld2MAC64
    //      st2MAC64
    //
    // The wrapper converts these instructions into the standard CVE2 LSU
    // request interface.
    //
    //======================================================================

    //
    // Generate an LSU request only for tile load/store instructions.
    //
    assign data_req_o =
           (cf_req_op_i == MAC_LD2) ||
           (cf_req_op_i == MAC_ST2);

    //
    // st2MAC64 performs a memory write.
    //
    assign data_we_o =
           (cf_req_op_i == MAC_ST2);

    //
    // Base address.
    //
    // rs1 contains the effective address already computed by software.
    //
    assign data_addr_o = req_rs1_i;

    //
    // Store data.
    //
    // IMPORTANT:
    //
    // This comes from the TILE, not rs2.
    //
    // The tile packs the selected pair of INT16 values into one 32-bit word.
    //
    assign data_wdata_o = st2_data;

    //
    // Entire 32-bit word is always transferred.
    //
    assign data_be_o = 4'b1111;


    //======================================================================
    // Request / Response Handshake
    //======================================================================
    //
    // This wrapper intentionally contains almost no control state.
    //
    // The current GEN1 MAC tile completes every instruction after receiving
    // a single-cycle enable pulse.
    //
    // Consequently:
    //
    //      req_valid_i
    //            │
    //            ▼
    //      dispatch pulse
    //            │
    //            ▼
    //      tile updates internal state
    //            │
    //            ▼
    //      instruction completes
    //
    // There is therefore no internal command queue, scoreboard or FSM.
    //
    // Future revisions (GEN2/GEN3) may introduce:
    //
    //      • multi-cycle MAC pipelines
    //      • pipelined load/store engine
    //      • multiple outstanding operations
    //      • BRAM post-processing
    //
    // At that point this section can be replaced by a small FSM while
    // leaving the remainder of the wrapper unchanged.
    //
    //======================================================================

    //
    // Always able to accept another request.
    //
    // Future multi-cycle versions may gate this using busy_o.
    //
    assign req_ready_o = 1'b1;

    //
    // No long-running operations in the current implementation.
    //
    assign busy_o = 1'b0;

    //
    // Signal completion whenever a valid instruction has been accepted.
    //
    // Since req_ready_o is permanently asserted, this simplifies to
    // req_valid_i.
    //
    assign done_o = req_valid_i;

    //======================================================================
    // Notes
    //======================================================================
    //
    // This wrapper intentionally does NOT:
    //
    //   • decode instruction opcodes
    //   • implement MAC arithmetic
    //   • implement tile storage
    //   • interpret FP4 operands
    //   • perform move operations
    //   • implement load/store semantics
    //
    // Those responsibilities belong entirely to fp4_mac8x8_gen1.
    //
    // Likewise, instruction decode belongs entirely to cve2_decoder.
    //
    // The wrapper's only responsibility is protocol adaptation between
    // the CVE2 pipeline and the MAC tile.
    //
    // This separation keeps the design modular:
    //
    //      cve2_decoder
    //            │
    //            ▼
    //      cve2_cf_unit
    //            │
    //            ▼
    //      fp4_mac8x8_gen1
    //
    // Any future enhancements to the tile (new instructions, deeper
    // pipelines, wider accumulators, etc.) should require minimal or no
    // changes to this wrapper.
    //
    //======================================================================

endmodule
