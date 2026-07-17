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
    input  cve2_pkg::mac_op_e          cf_req_op_i,
    input  logic [31:0]               req_instr_i,
    input  logic [31:0]               req_rs1_i,
    input  logic [31:0]               req_rs2_i,

    // Wrapper Global Status Signals
    output logic                      req_ready_o,
    output logic                      busy_o,
    output logic                      done_o,

    // Vector Register File Interface
    output logic [4:0]                mac_vrf_raddr_o,
    output logic [4:0]                mac_vrf_relem_o,
    input  logic [31:0]               mac_vrf_rdata_i
);

    localparam int TT = 8;

    //------------------------------------------------------------
    // Decoded Pipeline Instruction Configurations
    //------------------------------------------------------------
    logic [4:0]  vs1;
    logic unsigned [11:0] imm12;
    logic [31:0] weight_base;
    logic [31:0] weight_addr;

    assign vs1         = req_instr_i[11:7];
    assign imm12       = req_instr_i[31:20];
    assign weight_base = req_rs1_i;
    assign weight_addr = weight_base + imm12;

    // Instruction field parsing for moves
    logic [4:0]  mv_row;
    logic [4:0]  mv_pair;
    assign mv_row  = req_instr_i[19:15];
    assign mv_pair = req_instr_i[24:20];

    logic  map_mv_en;
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
    logic [1:0] scale_row_group; 

    // Selected tile values feeding scale units
    logic signed [15:0] scale_tile_value [0:1]; 

    // Direct real-time pulse triggers out from controller
    logic [31:0]        act_scale_lo, act_scale_hi;
    logic [31:0]        weight_scale_lo, weight_scale_hi;
    logic                act_scale_ready, weight_scale_ready;
    logic                snapshot_valid;

    // Global matrix snapshot configurations
    logic signed [15:0] tile_snapshot [0:TT-1][0:TT-1];

    //------------------------------------------------------------
    // WRAPPER PERSISTENT CONTEXT STORAGE AND STATE TRACKING
    //------------------------------------------------------------
    logic                snapshot_valid_q;
    logic                act_scale_valid_q;
    logic                weight_scale_valid_q;

    logic [31:0]        ctx_act_scale_lo;
    logic [31:0]        ctx_act_scale_hi;
    logic [31:0]        ctx_weight_scale_lo;
    logic [31:0]        ctx_weight_scale_hi;
    logic signed [15:0] ctx_tile_snapshot [0:TT-1][0:TT-1];

    logic                context_ready;
    logic                context_accept;
    logic                scale_busy;
    logic                scale_write;
    logic                scale_done;

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

            if (context_accept) begin
                snapshot_valid_q     <= 1'b0;
                act_scale_valid_q    <= 1'b0;
                weight_scale_valid_q <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------
    // Accumulator Block RAM Interconnect Signals
    //------------------------------------------------------------
    logic        bram_rd_en;
    logic [4:0]  bram_rd_tile;
    logic [2:0]  bram_rd_row;
    logic [2:0]  bram_rd_col;
    logic [15:0] bram_rd_data;

    logic        bram_wr_en;
    logic [4:0]  bram_wr_tile;
    logic [2:0]  bram_wr_row;
    logic [2:0]  bram_wr_col;
    logic [15:0] bram_wr_data;

    // Arbiter multiplexing between hardware sequencing FSM and system BIAS requests
    logic        ctrl_accum_rd_en;
    logic [4:0]  ctrl_accum_rd_tile;
    logic [2:0]  ctrl_accum_rd_row;
    logic [2:0]  ctrl_accum_rd_col;

    logic        ctrl_accum_wr_en;
    logic [4:0]  ctrl_accum_wr_tile;
    logic [2:0]  ctrl_accum_wr_row;
    logic [2:0]  ctrl_accum_wr_col;
    logic [15:0] ctrl_accum_wr_data;

    always_comb begin
        if (scale_busy) begin
            // Ports hold stable matched coordinates driven entirely by FSM logic
            bram_rd_en   = 1'b1;
            bram_rd_tile = 5'b0; 
            bram_rd_row  = scale_row_group; 
            bram_rd_col  = scale_col;

            // Commit write strictly during FSM WRITE phase to obey 1-cycle pipeline delay
            bram_wr_en   = scale_write;
            bram_wr_tile = 5'b0;
            bram_wr_row  = scale_row_group;
            bram_wr_col  = scale_col;
            bram_wr_data = scale_accum_out[0];
        end else begin
            // Relinquish control authority to master controller pipeline operations
            bram_rd_en   = ctrl_accum_rd_en;
            bram_rd_tile = ctrl_accum_rd_tile;
            bram_rd_row  = ctrl_accum_rd_row;
            bram_rd_col  = ctrl_accum_rd_col;

            bram_wr_en   = ctrl_accum_wr_en;
            bram_wr_tile = ctrl_accum_wr_tile;
            bram_wr_row  = ctrl_accum_wr_row;
            bram_wr_col  = ctrl_accum_wr_col;
            bram_wr_data = ctrl_accum_wr_data;
        end
    end

    //------------------------------------------------------------
    // Submodule Core Instantiations
    //------------------------------------------------------------
    logic        mac_en;
    logic        clear;
    logic [3:0]  act_vector [0:TT-1];
    logic [3:0]  weight_vector [0:TT-1];
    
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
        .weight_blk_i         (5'b0),
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
        .mv_en_o              (map_mv_en),
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
        
        // Structured BRAM hardware mapping connections
        .accum_rd_en_o        (ctrl_accum_rd_en),
        .accum_rd_tile_o      (ctrl_accum_rd_tile),
        .accum_rd_row_o       (ctrl_accum_rd_row),
        .accum_rd_col_o       (ctrl_accum_rd_col),
        .accum_rd_data_i      (bram_rd_data),
        .accum_wr_en_o        (ctrl_accum_wr_en),
        .accum_wr_tile_o      (ctrl_accum_wr_tile),
        .accum_wr_row_o       (ctrl_accum_wr_row),
        .accum_wr_col_o       (ctrl_accum_wr_col),
        .accum_wr_data_o      (ctrl_accum_wr_data)
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
        .mv_en_i              (map_mv_en),
        .mv_mode_i            (mv_mode),
        .mv_even_col_idx_i    (mv_even_col_idx),
        .mv_odd_col_idx_i     (mv_odd_col_idx),
        .mv_row_idx_i         (mv_row_idx)
    );

    mac_accum_bram u_accum_bram (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .rd_en_i              (bram_rd_en),
        .rd_tile_i            (bram_rd_tile),
        .rd_row_i             (bram_rd_row),
        .rd_col_i             (bram_rd_col),
        .rd_data_o            (bram_rd_data),
        .wr_en_i              (bram_wr_en),
        .wr_tile_i            (bram_wr_tile),
        .wr_row_i             (bram_wr_row),
        .wr_col_i             (bram_wr_col),
        .wr_data_i            (bram_wr_data)
    );

    assign mv_data =
            {
                tile_snapshot[mv_row_idx][mv_odd_col_idx],
                tile_snapshot[mv_row_idx][mv_even_col_idx]
            };

    mac_scale_fsm #(
        .NUM_GROUPS(32)
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
        .scale_write_o        (scale_write),
        .scale_done_o         (scale_done),
        .scale_col_o          (scale_col),
        .scale_row_group_o    (scale_row_group) 
    );

    //------------------------------------------------------------
    // SCALE TILE SELECTION (Using ctx stable registers)
    //------------------------------------------------------------
    always_comb begin
        scale_tile_value[0] = ctx_tile_snapshot[scale_row_group][scale_col];
        scale_tile_value[1] = ctx_tile_snapshot[scale_row_group + 2'd4][scale_col];
    end

    //------------------------------------------------------------
    // Processing Datapath Structures
    //------------------------------------------------------------
    logic [15:0] scale_accum_in  [0:1];
    logic [15:0] scale_accum_out [0:1];
    logic [7:0]  scaleA          [0:1];
    logic [7:0]  scaleB          [0:1];

    mac_scale_accum u_scale_accum0 (
        .tile_value(scale_tile_value[0]),
        .scaleA(scaleA[0]),
        .scaleB(scaleB[0]),
        .accumulator(scale_accum_in[0]),
        .accumulator_out(scale_accum_out[0])
    );

    mac_scale_accum u_scale_accum1 (
        .tile_value(scale_tile_value[1]),
        .scaleA(scaleA[1]),
        .scaleB(scaleB[1]),
        .accumulator(scale_accum_in[1]),
        .accumulator_out(scale_accum_out[1])
    );

    always_comb begin
        // Activation scales
        if (scale_row_group == 0) begin
            scaleA[0] = ctx_act_scale_lo[7:0];
            scaleA[1] = ctx_act_scale_lo[23:16];
        end
        else if (scale_row_group == 1) begin
            scaleA[0] = ctx_act_scale_lo[15:8];
            scaleA[1] = ctx_act_scale_lo[31:24];
        end
        else if (scale_row_group == 2) begin
            scaleA[0] = ctx_act_scale_hi[7:0];
            scaleA[1] = ctx_act_scale_hi[23:16];
        end
        else begin
            scaleA[0] = ctx_act_scale_hi[15:8];
            scaleA[1] = ctx_act_scale_hi[31:24];
        end

        // Weight scales
        if (scale_col < 4) begin
            scaleB[0] = ctx_weight_scale_lo[scale_col*8 +: 8];
            scaleB[1] = ctx_weight_scale_lo[scale_col*8 +: 8];
        end
        else begin
            scaleB[0] = ctx_weight_scale_hi[(scale_col-4)*8 +: 8];
            scaleB[1] = ctx_weight_scale_hi[(scale_col-4)*8 +: 8];
        end
    end

    // Connect structural data pipelines from physical storage ports 
    always_comb begin
        scale_accum_in[0] = bram_rd_data;
        scale_accum_in[1] = 16'h0000; // Standby structure tie-off
    end

    //------------------------------------------------------------
    // Simulation Debug Dumps
    //------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_ni) begin
            if (req_valid_i && req_ready_o) begin
                $display("[CVE2_MAC_DEBUG] [%0t ns] --- NEW INSTRUCTION EXECUTING ---", $time);
                $display("[CVE2_MAC_DEBUG] Opcode Type: %s | Instr: 32'h%h", cf_req_op_i.name(), req_instr_i);
                $display("[CVE2_MAC_DEBUG] RS1 (Weight Base): 32'h%h | RS2: 32'h%h", req_rs1_i, req_rs2_i);
                $display("[CVE2_MAC_DEBUG] Target Weight Linear Memory Addr: 32'h%h", weight_addr);
            end

            if (map_mv_en) begin
                $display("[CVE2_MAC_DEBUG] [%0t ns] SCALAR MOVE DETECTED:", $time);
                $display("[CVE2_MAC_DEBUG] Mode=%0d | RowIdx=%0d | ColPairs={%0d, %0d} -> WAddr=5'd%0d | WData=32'h%h",
                         mv_mode, mv_row_idx, mv_even_col_idx, mv_odd_col_idx, scalar_waddr_o, scalar_wdata_o);
            end

            if (snapshot_valid) begin
                $display("[CVE2_MAC_DEBUG] [%0t ns] --- CAPTURED 8x8 ARRAY SNAPSHOT MATRIX ---", $time);
                for (int r = 0; r < TT; r++) begin
                    $display("[CVE2_MAC_DEBUG] Row [%0d]: %5d %5d %5d %5d %5d %5d %5d %5d", r,
                             tile_snapshot[r][0], tile_snapshot[r][1], tile_snapshot[r][2], tile_snapshot[r][3],
                             tile_snapshot[r][4], tile_snapshot[r][5], tile_snapshot[r][6], tile_snapshot[r][7]);
                end
                $display("[CVE2_MAC_DEBUG] Act Scales captured:  LO=32'h%h | HI=32'h%h", act_scale_lo, act_scale_hi);
                $display("[CVE2_MAC_DEBUG] Weight Scales captured: LO=32'h%h | HI=32'h%h", weight_scale_lo, weight_scale_hi);
            end

            if (scale_busy) begin
                $display("[CVE2_MAC_DEBUG] [%0t ns] SCALE ELEMENT OPERATION:", $time);
                $display("[CVE2_MAC_DEBUG]   FSM Location: RowGroup=%0d | Col=%0d", scale_row_group, scale_col);
                $display("[CVE2_MAC_DEBUG]   Raw Tile Val: Upper=%5d | Lower=%5d", scale_tile_value[0], scale_tile_value[1]);
                $display("[CVE2_MAC_DEBUG]   Scale Factors: ActScale=%02x | WtScale=%02x", scaleA[0], scaleB[0]);
                $display("[CVE2_MAC_DEBUG]   BRAM Accumulator Pipelines: In=%04h -> Out=%04h", scale_accum_in[0], scale_accum_out[0]);
                if (bram_wr_en) begin
                    $display("[CVE2_MAC_DEBUG]   --> BRAM WRITE: Tile=%0d | Row=%0d | Col=%0d | Data=16'h%h",
                             bram_wr_tile, bram_wr_row, bram_wr_col, bram_wr_data);
                end
            end
            
            if (!scale_busy && bram_wr_en) begin
                $display("[CVE2_MAC_DEBUG] [%0t ns] DIRECT BIAS ACCUMULATOR WRITE OVERRIDE:", $time);
                $display("[CVE2_MAC_DEBUG]   Target Address Coordinates -> Tile=%0d | Row=%0d | Col=%0d | Payload=16'h%h", 
                         bram_wr_tile, bram_wr_row, bram_wr_col, bram_wr_data);
            end
        end
    end

endmodule
