`timescale 1ns/1ps

module cve2_cf_mac_unit
(
    // Unused or specialized scalar connections
    output logic                      scalar_we_o,
    output logic [4:0]                scalar_waddr_o,
    output logic [31:0]               scalar_wdata_o,

    // Primary System Memory Interconnect Interface
    output logic                      data_req_o,
    input  logic                      data_gnt_i,
    output logic [31:0]               data_addr_o,
    output logic                      data_we_o,
    output logic [3:0]                data_be_o,
    output logic [31:0]               data_wdata_o,

    input  logic [31:0]               data_rdata_i,
    input  logic                      data_rvalid_i,
    input  logic                      data_err_i,

    input  logic                      clk_i,
    input  logic                      rst_ni,

    // CVE2 Pipeline execution Request Interface
    input  logic                      req_valid_i,
    input  cve2_pkg::mac_op_e         cf_req_op_i,
    input  logic [31:0]               req_instr_i,
    input  logic [31:0]               req_rs1_i,
    input  logic [31:0]               req_rs2_i,

    // Wrapper Global Status Signals
    output logic                      req_ready_o,
    output logic                      busy_o,
    output logic                      done_o,

    // Vector Register File Interface
    output logic [4:0]                mac_vrf_raddr_o,
    output logic [2:0]                mac_vrf_relem_o,
    input  logic [31:0]               mac_vrf_rdata_i
);

    localparam int TT = 8;

    //------------------------------------------------------------
    // Decoded Pipeline Instruction Configurations
    //------------------------------------------------------------
    logic [4:0]  vs1;
    logic [11:0] imm12;
    logic [31:0] weight_base;
    logic [31:0] weight_addr;

    assign vs1         = req_instr_i[11:7];
    assign imm12       = req_instr_i[31:20];
    assign weight_base = req_rs1_i;
    assign weight_addr = weight_base + {{20{imm12[11]}}, imm12};

    // Instruction field parsing for moves
    logic [4:0]  mv_row;
    logic [4:0]  mv_pair;
    assign mv_row  = req_instr_i[19:15];
    assign mv_pair = req_instr_i[24:20];

    logic        mv_en;
    logic [1:0]  mv_mode;   
    logic [2:0]  mv_even_col_idx;
    logic [2:0]  mv_odd_col_idx;
    logic [2:0]  mv_row_idx;
    logic [31:0] mv_data;
    assign scalar_wdata_o = mv_data;

    logic [4:0]  scalar_waddr;
    assign scalar_waddr = req_instr_i[11:7];

    //------------------------------------------------------------
    // Scale Processing Datapath Interconnect Intermediates
    //------------------------------------------------------------
    logic [2:0] scale_col;    
    logic       scale_row_sel;

    // Selected tile values feeding scale units
    logic signed [15:0] scale_tile_value [0:3];

    // Direct real-time pulse triggers out from controller
    logic [31:0]        act_scale_lo, act_scale_hi;
    logic [31:0]        weight_scale_lo, weight_scale_hi;
    logic               act_scale_ready, weight_scale_ready;
    logic               snapshot_valid;

    // Global matrix snapshot configurations
    logic signed [15:0] tile_snapshot [0:TT-1][0:TT-1];

    //------------------------------------------------------------
    // WRAPPER PERSISTENT CONTEXT STORAGE AND STATE TRACKING
    //------------------------------------------------------------
    logic               snapshot_valid_q;
    logic               act_scale_valid_q;
    logic               weight_scale_valid_q;

    logic [31:0]        ctx_act_scale_lo;
    logic [31:0]        ctx_act_scale_hi;
    logic [31:0]        ctx_weight_scale_lo;
    logic [31:0]        ctx_weight_scale_hi;
    logic signed [15:0] ctx_tile_snapshot [0:TT-1][0:TT-1];

    logic               context_ready;
    logic               context_accept;
    logic               scale_busy;
    logic               scale_done;

    // Assemble persistent context assembly status
    assign context_ready = snapshot_valid_q && act_scale_valid_q && weight_scale_valid_q;

    // Context capturing and validation reset tracking block
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            snapshot_valid_q     <= 1'b0;
            act_scale_valid_q    <= 1'b0;
            weight_scale_valid_q <= 1'b0;
            ctx_act_scale_lo     <= '0;
            ctx_act_scale_hi     <= '0;
            ctx_weight_scale_lo  <= '0;
            ctx_weight_scale_hi  <= '0;
            for (int r = 0; r < TT; r++) begin
                for (int c = 0; c < TT; c++) begin
                    ctx_tile_snapshot[r][c] <= '0;
                end
            end
        end else begin
            // 1. Capture incoming real-time pulses from sequencing controller
            if (snapshot_valid && !scale_busy) begin
                snapshot_valid_q  <= 1'b1;
                ctx_tile_snapshot <= tile_snapshot;
            end

            if (act_scale_ready) begin
                act_scale_valid_q <= 1'b1;
                ctx_act_scale_lo  <= act_scale_lo;
                ctx_act_scale_hi  <= act_scale_hi;
            end

            if (weight_scale_ready) begin
                weight_scale_valid_q <= 1'b1;
                ctx_weight_scale_lo  <= weight_scale_lo;
                ctx_weight_scale_hi  <= weight_scale_hi;
            end

            // 2. Clear out state flags simultaneously when the Scale processing engine consumes them
            if (context_accept) begin
                snapshot_valid_q     <= 1'b0;
                act_scale_valid_q    <= 1'b0;
                weight_scale_valid_q <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------
    // Submodule Core Instantiations
    //------------------------------------------------------------
    logic        mac_en;
    logic        clear;
    logic [3:0]  act_vector [0:TT-1];
    logic [3:0]  weight_vector [0:TT-1];
    
    // Internal interconnect mapping
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

    mac_controller #(
        .VL(32),
        .TT(TT)
    ) u_ctrl (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .req_valid_i          (req_valid_i),
        .cf_req_op_i          (cf_req_op_i),
        .rs1_i                (req_rs1_i),
        .rs2_i                (req_rs2_i),
        .mac_en_o             (mac_en),
        .clear_o              (clear),
        .vs1_i                (vs1),
        .weight_blk_i         (5'b0), // Unused parameter structural tie-off
        .base_i               (weight_addr),
        .mac_vrf_raddr_o      (mac_vrf_raddr_o),
        .mac_vrf_relem_o      (mac_vrf_relem_o),
        .data_req_o           (mem_req),
        .data_gnt_i           (data_gnt_i),
        .data_addr_o          (mem_addr),
        .data_we_o            (mem_we),
        .data_be_o            (mem_be),
        .data_wdata_o         (mem_wdata),
        .data_rvalid_i        (data_rvalid_i),
        .data_rdata_i         (data_rdata_i),
        .data_err_i           (data_err_i),
        .act_vector_o         (act_vector),
        .weight_vector_o      (weight_vector),
        .mac_vrf_rdata_i      (mac_vrf_rdata_i),
        .mv_en_o              (mv_en),
        .mv_mode_o            (mv_mode),
        .mv_even_col_idx_o    (mv_even_col_idx),
        .mv_odd_col_idx_o     (mv_odd_col_idx),
        .mv_row_idx_o         (mv_row_idx),
        .mv_row_i             (mv_row),
        .mv_pair_i            (mv_pair),
        .scalar_waddr_i       (scalar_waddr),
        .scalar_waddr_o       (scalar_waddr_o),
        .scalar_we_o          (scalar_we_o),
        .act_scale_lo_o       (act_scale_lo),
        .act_scale_hi_o       (act_scale_hi),
        .weight_scale_lo_o    (weight_scale_lo),
        .weight_scale_hi_o    (weight_scale_hi),
        .act_scale_ready_o    (act_scale_ready),
        .weight_scale_ready_o (weight_scale_ready),
        .mac_snapshot_valid_o (snapshot_valid),
        .scale_busy_i         (scale_busy),
        .scale_done_i         (scale_done),
        .req_ready_o          (req_ready_o),
        .busy_o               (busy_o),
        .done_o               (done_o),
	.mac_acc_en_o  (mac_acc_en), // bias signals
	.mac_acc_row_o (mac_acc_row),
	.mac_acc_col_o (mac_acc_col),
	.mac_bias_word_o(mac_bias_word) 
    );

    mac_array #(
        .TT(TT)
    ) u_array (
        .clk                  (clk_i),
        .rst_n                (rst_ni),
        .mac_en_i             (mac_en),
        .clear_i              (clear),
        .act_i                (act_vector),
        .wt_i                 (weight_vector),
        .accum_o              (tile_snapshot),
        .mv_en_i              (mv_en),
        .mv_mode_i            (mv_mode),
        .mv_even_col_idx_i    (mv_even_col_idx),
        .mv_odd_col_idx_i     (mv_odd_col_idx),
        //.mv_data_o            (mv_data),
        .mv_row_idx_i         (mv_row_idx)
    );


//TEMP CONVERT FOR MV2
	assign mv_data =
            {
                scale_accum_tile [mv_row_idx][mv_odd_col_idx],
                scale_accum_tile [mv_row_idx][mv_even_col_idx]
            };



    mac_scale_fsm #(
        .NUM_GROUPS(16)
    ) u_scale_fsm (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .context_ready_i      (context_ready),
        .context_accept_o     (context_accept),
        .act_scale_lo_i       (ctx_act_scale_lo),
        .act_scale_hi_i       (ctx_act_scale_hi),
        .weight_scale_lo_i    (ctx_weight_scale_lo),
        .weight_scale_hi_i    (ctx_weight_scale_hi),
        .tile_snapshot_i      (ctx_tile_snapshot),
        .scale_busy_o         (scale_busy),
        .scale_done_o         (scale_done),
	.scale_col_o	      (scale_col),
	.scale_row_sel_o      (scale_row_sel)
    );

    //------------------------------------------------------------
    // SCALE TILE SELECTION
    //
    // Four scale units process one column at a time.
    // Each unit receives one value from a row pair.
    //
    // scale_row_sel = 0:
    //   rows 0,2,4,6
    //
    // scale_row_sel = 1:
    //   rows 1,3,5,7
    //------------------------------------------------------------

    always_comb begin

        scale_tile_value[0] =
            tile_snapshot[scale_row_sel ? 1 : 0][scale_col];

        scale_tile_value[1] =
            tile_snapshot[scale_row_sel ? 3 : 2][scale_col];

        scale_tile_value[2] =
            tile_snapshot[scale_row_sel ? 5 : 4][scale_col];

        scale_tile_value[3] =
            tile_snapshot[scale_row_sel ? 7 : 6][scale_col];

    end

    //------------------------------------------------------------
    // Processing Datapath Structures (Placeholders/Verification)
    //------------------------------------------------------------
    logic [15:0] scale_accum_in  [0:3];
    logic [15:0] scale_accum_out [0:3];
    logic [7:0]  scaleA          [0:3];
    logic [7:0]  scaleB          [0:3];

//    mac_scale_accum u_scale_accum0 (
//        .tile_value(scale_tile_value[0]),
//        .scaleA(scaleA[0]),
//        .scaleB(scaleB[0]),
//        .accumulator(scale_accum_in[0]),
//        .accumulator_out(scale_accum_out[0])
//    );

//    mac_scale_accum u_scale_accum1 (
//        .tile_value(scale_tile_value[1]),
//        .scaleA(scaleA[1]),
//        .scaleB(scaleB[1]),
//        .accumulator(scale_accum_in[1]),
//        .accumulator_out(scale_accum_out[1])
//    );

//    mac_scale_accum u_scale_accum2 (
//        .tile_value(scale_tile_value[2]),
//        .scaleA(scaleA[2]),
//        .scaleB(scaleB[2]),
//        .accumulator(scale_accum_in[2]),
//        .accumulator_out(scale_accum_out[2])
//    );

//    mac_scale_accum u_scale_accum3 (
//        .tile_value(scale_tile_value[3]),
//        .scaleA(scaleA[3]),
//        .scaleB(scaleB[3]),
//        .accumulator(scale_accum_in[3]),
//        .accumulator_out(scale_accum_out[3])
//    );

//E4M3 

    e4m3_scale u_scale_accum0 (
        .acc_q14_2_in(scale_tile_value[0]),
        .a_scale_in(scaleA[0]),
        .w_scale_in(scaleB[0]),
        .bf16_in(scale_accum_in[0]),
        .bf16_out(scale_accum_out[0])
    );

    e4m3_scale u_scale_accum1 (
        .acc_q14_2_in(scale_tile_value[1]),
        .a_scale_in(scaleA[1]),
        .w_scale_in(scaleB[1]),
        .bf16_in(scale_accum_in[1]),
        .bf16_out(scale_accum_out[1])
    );

    e4m3_scale u_scale_accum2 (
        .acc_q14_2_in(scale_tile_value[2]),
        .a_scale_in(scaleA[2]),
        .w_scale_in(scaleB[2]),
        .bf16_in(scale_accum_in[2]),
        .bf16_out(scale_accum_out[2])
    );

    e4m3_scale u_scale_accum3 (
        .acc_q14_2_in(scale_tile_value[3]),
        .a_scale_in(scaleA[3]),
        .w_scale_in(scaleB[3]),
        .bf16_in(scale_accum_in[3]),
        .bf16_out(scale_accum_out[3])
    );

 //E4M3_end


always_comb begin

    //------------------------------------------
    // Activation scales
    //------------------------------------------

    if (!scale_row_sel) begin
        // rows 0,2,4,6
        scaleA[0] = ctx_act_scale_lo[ 7: 0];
        scaleA[1] = ctx_act_scale_lo[23:16];
        scaleA[2] = ctx_act_scale_hi[ 7: 0];
        scaleA[3] = ctx_act_scale_hi[23:16];
    end
    else begin
        // rows 1,3,5,7
        scaleA[0] = ctx_act_scale_lo[15: 8];
        scaleA[1] = ctx_act_scale_lo[31:24];
        scaleA[2] = ctx_act_scale_hi[15: 8];
        scaleA[3] = ctx_act_scale_hi[31:24];
    end

    //------------------------------------------
    // Weight scales
    //------------------------------------------

    if (scale_col < 4) begin
        scaleB[0] = ctx_weight_scale_lo[ 7: 0];
        scaleB[1] = ctx_weight_scale_lo[15: 8];
        scaleB[2] = ctx_weight_scale_lo[23:16];
        scaleB[3] = ctx_weight_scale_lo[31:24];
    end
    else begin
        scaleB[0] = ctx_weight_scale_hi[ 7: 0];
        scaleB[1] = ctx_weight_scale_hi[15: 8];
        scaleB[2] = ctx_weight_scale_hi[23:16];
        scaleB[3] = ctx_weight_scale_hi[31:24];
    end

end

//    always_comb begin
  //      scaleA[0] = 8'h7F;  scaleA[1] = 8'h80;  scaleA[2] = 8'h7E;  scaleA[3] = 8'h80; //[stev] - need to collect these
   //     scaleB[0] = 8'h7F;  scaleB[1] = 8'h7F;  scaleB[2] = 8'h7F;  scaleB[3] = 8'h80;
    //    scale_accum_in[0] = 16'h4302; scale_accum_in[1] = 16'h4302; scale_accum_in[2] = 16'h4302; scale_accum_in[3] = 16'h4302;
    //end

//to_RM
//always_comb begin

    // ------------------------------------------------------------
    // Fake BF16 accumulator values
    // Give each group a unique starting point
    // ------------------------------------------------------------
 //   scale_accum_in[0] = 16'h4300;
//    scale_accum_in[1] = 16'h4400;
//    scale_accum_in[2] = 16'h4500;
//    scale_accum_in[3] = 16'h4600;

//end

//------------------------------------------------------------
// Read four accumulator cells
//------------------------------------------------------------

always_comb begin

    if (!scale_row_sel) begin

        scale_accum_in[0] = scale_accum_tile[0][scale_col];
        scale_accum_in[1] = scale_accum_tile[2][scale_col];
        scale_accum_in[2] = scale_accum_tile[4][scale_col];
        scale_accum_in[3] = scale_accum_tile[6][scale_col];

    end
    else begin

        scale_accum_in[0] = scale_accum_tile[1][scale_col];
        scale_accum_in[1] = scale_accum_tile[3][scale_col];
        scale_accum_in[2] = scale_accum_tile[5][scale_col];
        scale_accum_in[3] = scale_accum_tile[7][scale_col];

    end

end

//BRAM emulation here
logic signed [15:0] scale_accum_tile [0:TT-1][0:TT-1];

//------------------------------------------------------------
// Software BRAM model
// 8x8 accumulator tile
//------------------------------------------------------------

logic        mac_acc_en;
logic [2:0]  mac_acc_row;
logic [2:0]  mac_acc_col;
logic [31:0]          mac_bias_word;

integer r,c;

//------------------------------------------------------------
// Software BRAM Block Execution
//------------------------------------------------------------
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        for (r=0; r<TT; r++) begin
            for (c=0; c<TT; c++) begin
                scale_accum_tile[r][c] <= 16'h0000;
            end
        end
    end
    else begin
        //--------------------------------------------------
        // Existing scaler writeback (Highest priority write)
        //--------------------------------------------------
        if (scale_busy) begin
            if (!scale_row_sel) begin
                scale_accum_tile[0][scale_col] <= scale_accum_out[0];
                scale_accum_tile[2][scale_col] <= scale_accum_out[1];
                scale_accum_tile[4][scale_col] <= scale_accum_out[2];
                scale_accum_tile[6][scale_col] <= scale_accum_out[3];
            end
            else begin
                scale_accum_tile[1][scale_col] <= scale_accum_out[0];
                scale_accum_tile[3][scale_col] <= scale_accum_out[1];
                scale_accum_tile[5][scale_col] <= scale_accum_out[2];
                scale_accum_tile[7][scale_col] <= scale_accum_out[3];
            end
        end
        //--------------------------------------------------
        // MACACC bias accumulation (Runs when scaling pipeline is idle)
        //--------------------------------------------------
        else if (mac_acc_en) begin 
           // lower 16 bits -> even column
    		scale_accum_tile[mac_acc_row][mac_acc_col] <= scale_accum_tile[mac_acc_row][mac_acc_col] + mac_bias_word[15:0];

    	// upper 16 bits -> odd column
    		scale_accum_tile[mac_acc_row][mac_acc_col+1'b1] <= scale_accum_tile[mac_acc_row][mac_acc_col+1'b1] + mac_bias_word[31:16];

$display("[%0t] [MACACC_WR] row=%0d col=%0d bias_lo=%04h bias_hi=%04h old_lo=%04h old_hi=%04h",
             $time,
             mac_acc_row,
             mac_acc_col,
             mac_bias_word[15:0],
             mac_bias_word[31:16],
             scale_accum_tile[mac_acc_row][mac_acc_col],
             scale_accum_tile[mac_acc_row][mac_acc_col+1]);

        end
    end
end
//to_RM_end

// --- [stev] ---
always_ff @(posedge clk_i) begin
    if (scale_busy) begin
        $display("[%0t] [SCALE_RD] row_sel=%0d col=%0d",
                 $time,
                 scale_row_sel,
                 scale_col);

        if (!scale_row_sel) begin
            $display(" rows 0,2,4,6 values=%04h %04h %04h %04h",
                     scale_accum_tile[0][scale_col],
                     scale_accum_tile[2][scale_col],
                     scale_accum_tile[4][scale_col],
                     scale_accum_tile[6][scale_col]);
        end
        else begin
            $display(" rows 1,3,5,7 values=%04h %04h %04h %04h",
                     scale_accum_tile[1][scale_col],
                     scale_accum_tile[3][scale_col],
                     scale_accum_tile[5][scale_col],
                     scale_accum_tile[7][scale_col]);
        end
    end
end

// ------------------------------------------------------------
// Scale Accumulator Tile Dump
// ------------------------------------------------------------
always_ff @(posedge clk_i) begin
    if (rst_ni) begin

        $display("");
        $display("======================================================");
        $display("[%0t] SCALE ACCUMULATOR", $time);
        $display("======================================================");

        $display("FSM:");
        $display("  row_sel=%0d col=%0d busy=%0b done=%0b",
                 scale_row_sel,
                 scale_col,
                 scale_busy,
                 scale_done);

        $display("");

        $display("Selected MAC Tile:");
        $display("  tile = {%0d, %0d, %0d, %0d}",
                 scale_tile_value[0],
                 scale_tile_value[1],
                 scale_tile_value[2],
                 scale_tile_value[3]);

        $display("");

        $display("Scale Factors:");
        $display("  A = {%02x,%02x,%02x,%02x}",
                 scaleA[0],
                 scaleA[1],
                 scaleA[2],
                 scaleA[3]);

        $display("  B = {%02x,%02x,%02x,%02x}",
                 scaleB[0],
                 scaleB[1],
                 scaleB[2],
                 scaleB[3]);

        $display("");

        $display("Accumulator:");
        $display("  IN  = {%04h,%04h,%04h,%04h}",
                 scale_accum_in[0],
                 scale_accum_in[1],
                 scale_accum_in[2],
                 scale_accum_in[3]);

        $display("  OUT = {%04h,%04h,%04h,%04h}",
                 scale_accum_out[0],
                 scale_accum_out[1],
                 scale_accum_out[2],
                 scale_accum_out[3]);

        $display("");

        $display("Accumulated BF16 Tile:");

        for (int r = 0; r < TT; r++) begin
            $write("Row %0d :", r);
            for (int c = 0; c < TT; c++) begin
                $write(" %04h", scale_accum_tile[r][c]);
            end
            $write("\n");
        end

        $display("======================================================");
        $display("");

    end
end


always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        $display("[%0t] [SCALE] row_sel=%0b col=%0d rows={%0d,%0d,%0d,%0d} tile={%0d,%0d,%0d,%0d} acc_in={%04h,%04h,%04h,%04h} acc_out={%04h,%04h,%04h,%04h}",
                 $time,
                 scale_row_sel,
                 scale_col,
                 (scale_row_sel ? 1 : 0),
                 (scale_row_sel ? 3 : 2),
                 (scale_row_sel ? 5 : 4),
                 (scale_row_sel ? 7 : 6),
                 scale_tile_value[0],
                 scale_tile_value[1],
                 scale_tile_value[2],
                 scale_tile_value[3],
                 scale_accum_in[0],
                 scale_accum_in[1],
                 scale_accum_in[2],
                 scale_accum_in[3],
                 scale_accum_out[0],
                 scale_accum_out[1],
                 scale_accum_out[2],
                 scale_accum_out[3]);
    end
end

// ------------------------------------------------------------
// Scale Context Debug Dump
// ------------------------------------------------------------
always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        $display("[%0t] [SCALE_CTX] act_lo=%08x act_hi=%08x wt_lo=%08x wt_hi=%08x",
                 $time,
                 ctx_act_scale_lo,
                 ctx_act_scale_hi,
                 ctx_weight_scale_lo,
                 ctx_weight_scale_hi);

        $display("[%0t] [SCALE_CTX] ACT scales = {%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x}",
                 $time,
                 ctx_act_scale_lo[7:0],
                 ctx_act_scale_lo[15:8],
                 ctx_act_scale_lo[23:16],
                 ctx_act_scale_lo[31:24],
                 ctx_act_scale_hi[7:0],
                 ctx_act_scale_hi[15:8],
                 ctx_act_scale_hi[23:16],
                 ctx_act_scale_hi[31:24]);

        $display("[%0t] [SCALE_CTX] WT scales  = {%02x,%02x,%02x,%02x,%02x,%02x,%02x,%02x}",
                 $time,
                 ctx_weight_scale_lo[7:0],
                 ctx_weight_scale_lo[15:8],
                 ctx_weight_scale_lo[23:16],
                 ctx_weight_scale_lo[31:24],
                 ctx_weight_scale_hi[7:0],
                 ctx_weight_scale_hi[15:8],
                 ctx_weight_scale_hi[23:16],
                 ctx_weight_scale_hi[31:24]);

        $display("[%0t] [SCALE_SEL] row_sel=%0b col=%0d | scaleA={%02x,%02x,%02x,%02x} scaleB={%02x,%02x,%02x,%02x}",
                 $time,
                 scale_row_sel,
                 scale_col,
                 scaleA[0],
                 scaleA[1],
                 scaleA[2],
                 scaleA[3],
                 scaleB[0],
                 scaleB[1],
                 scaleB[2],
                 scaleB[3]);
    end
end

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

always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        $display("[%0t] [MAC_MV] op=%0d mv_en=%0b mode=%0d row=%0d even_col=%0d odd_col=%0d",
                 $time,
                 cf_req_op_i,
                 mv_en,
                 mv_mode,
                 mv_row_idx,
                 mv_even_col_idx,
                 mv_odd_col_idx);

        if (mv_en) begin
            $display("[%0t] [MAC_MV] DATA_OUT=%08x scalar_we=%0b scalar_waddr=x%0d",
                     $time,
                     mv_data,
                     scalar_we_o,
                     scalar_waddr_o);

            $display("[%0t] [MAC_MV] TILE[%0d][%0d]=%0d TILE[%0d][%0d]=%0d",
                     $time,
                     mv_row_idx,
                     mv_even_col_idx,
                     tile_snapshot[mv_row_idx][mv_even_col_idx],
                     mv_row_idx,
                     mv_odd_col_idx,
                     tile_snapshot[mv_row_idx][mv_odd_col_idx]);
        end
    end
end

always_ff @(posedge clk_i) begin
    if (rst_ni) begin
        $display("[%0t] [CTX] snap=%0b act=%0b wt=%0b ready=%0b accept=%0b busy=%0b done=%0b",
                 $time,
                 snapshot_valid_q,
                 act_scale_valid_q,
                 weight_scale_valid_q,
                 context_ready,
                 context_accept,
                 scale_busy,
                 scale_done);
    end
end

always_ff @(posedge clk_i) begin
    if (snapshot_valid) begin
        $display("[%0t] Snapshot captured", $time);

        for (int r=0; r<TT; r++) begin
            $write("Row %0d :", r);
            for (int c=0; c<TT; c++)
                $write(" %6d", tile_snapshot[r][c]);
            $write("\n");
        end
    end
end
// --- [end] ---

endmodule
