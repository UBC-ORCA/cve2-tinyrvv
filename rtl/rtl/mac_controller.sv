module mac_controller #(
    parameter int VL = 32, // Updated default to 32 to support the 32 flattened MAC iterations
    parameter int TT = 8
) (
    input  logic                 clk_i,
    input  logic                 rst_ni,

    // Request interface
    input  logic                 req_valid_i,
    output logic                 req_ready_o,
    input  cve2_pkg::mac_op_e    cf_req_op_i,
    input  logic [31:0]          rs1_i,
    input  logic [31:0]          rs2_i,

    // Status outputs
    output logic                 busy_o,
    output logic                 done_o,

    // Control to MAC array
    output logic                 mac_en_o,
    output logic                 mac_acc_en_o, // Controls bias accumulation execution
    output logic                 clear_o,

    // --- [stev] ---
    input  logic [4:0]           vs1_i,
    input  logic [4:0]           weight_blk_i,
    input  logic [31:0]          base_i,

    output logic [4:0]           mac_vrf_raddr_o,
    output logic [2:0]           mac_vrf_relem_o,
    input  logic [31:0]          mac_vrf_rdata_i, 

    // Weight memory interface
    output logic                 data_req_o,
    input  logic                 data_gnt_i,

    output logic [31:0]          data_addr_o,
    output logic                 data_we_o,
    output logic [3:0]           data_be_o,
    output logic [31:0]          data_wdata_o,

    input  logic                 data_rvalid_i,
    input  logic [31:0]          data_rdata_i,
    input  logic                 data_err_i,

    // mv inst
    output logic                 mv_en_o,
    output logic [1:0]           mv_mode_o,
    output logic [2:0]           mv_even_col_idx_o,
    output logic [2:0]           mv_odd_col_idx_o,
    output logic [2:0]           mv_row_idx_o,
    input  logic [4:0]           mv_row_i,
    input  logic [4:0]           mv_pair_i,

    output logic                 scalar_we_o,
    output logic [4:0]           scalar_waddr_o,
    input  logic [4:0]           scalar_waddr_i,

    // Optimized Vector Slices
    output logic [3:0]           act_vector_o    [0:TT-1],
    output logic [3:0]           weight_vector_o [0:TT-1],

    // Scale register interface
    output logic [31:0]          act_scale_lo_o,
    output logic [31:0]          act_scale_hi_o,
    output logic [31:0]          weight_scale_lo_o,
    output logic [31:0]          weight_scale_hi_o,

    output logic                 act_scale_ready_o,
    output logic                 weight_scale_ready_o,
    output logic                 mac_snapshot_valid_o,

    // Scale FSM handshake ports
    input  logic                 scale_busy_i,
    input  logic                 scale_done_i,

    // --- [Patched Output Interfaces] ---
    output logic [2:0]           mac_acc_row_o,  // Decoded Row index (0-7)
    output logic [2:0]           mac_acc_col_o,  // Decoded Column index (0-7)
    output logic [31:0]          mac_bias_word_o // Raw 32-bit word from VRF
);

    logic [31:0] act_scale_lo_q;
    logic [31:0] act_scale_hi_q;
    logic [31:0] weight_scale_lo_q;
    logic [31:0] weight_scale_hi_q;

    logic        snapshot_valid_q;
    logic        act_scale_pulse;
    logic        weight_scale_pulse;

    logic [4:0]  vs1_q;
    logic [4:0]  weight_blk_q;
    logic [31:0] base_q;

    logic        mem_req_sent_q;
    logic        mem_req_sent_d;

    cve2_pkg::mac_op_e op_q;

    localparam int CNT_W = $clog2(VL);
    logic [CNT_W-1:0] count_q;
    logic [CNT_W-1:0] count_d;

    //------------------------------------------------------------
    // Patched: Flattened VRF traversal decoding logic
    //------------------------------------------------------------
    logic [1:0] reg_group;
    logic [2:0] elem_idx;
    logic [4:0] mac_vrf_addr;

    assign reg_group    = count_q[4:3]; // Decodes register offset (0..3)
    assign elem_idx     = count_q[2:0]; // Decodes element index within register (0..7)
    assign mac_vrf_addr = vs1_q + reg_group;

    // Patched: Register to delay the snapshot by 1 clock cycle 
    logic        vmac_last_q;

    //------------------------------------------------------------
    // Patched: MACACC Dedicated Counter & Traversal Decode
    //
    // One vector register:
    //   8 x 32-bit words
    //   16 x BF16 values
    //   2 accumulator rows
    //
    // acc_count_q:
    //   0-7 = VRF word index
    //------------------------------------------------------------
    localparam int ACC_VL = 8;
    localparam int ACC_CNT_W = $clog2(ACC_VL);

    logic [ACC_CNT_W-1:0] acc_count_q;
    logic [ACC_CNT_W-1:0] acc_count_d;

    // Latched bias vector register
    logic [4:0]           bias_vs_q;

    // VRF word index
    logic [2:0]           acc_word_idx;

    // row inside vector register
    logic                 acc_row_offset;

    // column base (two BF16 per word)
    logic [2:0]           acc_col_base;

    // VRF address for MACACC
    logic [4:0]           acc_vrf_addr;

    // Decode current word
    assign acc_word_idx   = acc_count_q;

    // First 4 words = first row, last 4 words = second row
    assign acc_row_offset = acc_count_q[2];

    // Word 0 -> columns 0,1
    // Word 1 -> columns 2,3
    // Word 2 -> columns 4,5
    // Word 3 -> columns 6,7
    assign acc_col_base   = {acc_count_q[1:0], 1'b0};

    // One MACACC instruction operates on one VRF register
    assign acc_vrf_addr   = bias_vs_q;

    //------------------------------------------------------------
    // Accumulator destination
    //
    // vs1 selects the two-row block:
    //   v0 -> rows 0,1
    //   v1 -> rows 2,3
    //   v2 -> rows 4,5
    //   v3 -> rows 6,7
    //------------------------------------------------------------
    assign mac_acc_row_o  = {bias_vs_q[1:0], acc_row_offset};
    assign mac_acc_col_o  = acc_col_base;

    //------------------------------------------------------------
    // Patched: Bias Word Output (Forwarding 32-bit word from VRF)
    //------------------------------------------------------------
    assign mac_bias_word_o = mac_vrf_rdata_i;

    //------------------------------------------------------------
    // Patched: FSM States (Patch 1)
    //------------------------------------------------------------
    typedef enum logic [1:0] { IDLE, EXEC, WAIT_SCALE, DONE } state_e;
    state_e state_q, state_d;

    logic [31:0] act_packed;
    logic [31:0] weight_packed;

    always_comb begin
        act_packed    = mac_vrf_rdata_i;
        weight_packed = data_rdata_i;
        if (op_q == cve2_pkg::OP_MAC) begin
            act_packed    = rs1_i;
            weight_packed = rs2_i;
        end
    end

    localparam logic [1:0] MV_EVEN = 2'd0;
    localparam logic [1:0] MV_ODD  = 2'd1;
    localparam logic [1:0] MV_PAIR = 2'd2;

    logic [1:0] mv_pair_idx;
    assign mv_row_idx_o      = mv_row_i[2:0];
    assign mv_pair_idx       = mv_pair_i[1:0];
    assign mv_even_col_idx_o = {mv_pair_idx, 1'b0};
    assign mv_odd_col_idx_o  = {mv_pair_idx, 1'b1};

    logic [4:0] scalar_waddr_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            op_q               <= cve2_pkg::OP_ZZ;
            vs1_q              <= '0;
            weight_blk_q       <= '0; 
            base_q             <= '0; 
            state_q            <= IDLE;
            count_q            <= '0;
            mem_req_sent_q     <= 1'b0;
            scalar_waddr_q     <= '0;
            act_scale_lo_q     <= '0;
            act_scale_hi_q     <= '0;
            weight_scale_lo_q  <= '0;
            weight_scale_hi_q  <= '0;
            snapshot_valid_q   <= 1'b0;
            act_scale_pulse    <= 1'b0;
            weight_scale_pulse <= 1'b0;
            vmac_last_q        <= 1'b0;
            // MACACC Reset
            acc_count_q        <= '0;
            bias_vs_q          <= '0;
        end else begin
            state_q            <= state_d;
            count_q            <= count_d;
            acc_count_q        <= acc_count_d;
            mem_req_sent_q     <= mem_req_sent_d;
            
            snapshot_valid_q   <= 1'b0;
            act_scale_pulse    <= 1'b0;
            weight_scale_pulse <= 1'b0;

            if (req_valid_i && req_ready_o) begin
                op_q           <= cf_req_op_i;
                vs1_q          <= vs1_i;
                weight_blk_q   <= weight_blk_i;
                base_q         <= base_i;
                scalar_waddr_q <= scalar_waddr_i;
                // Latch Vs1 as base for bias register offset during MACACC
                bias_vs_q      <= vs1_i;

                unique case (cf_req_op_i)
                    cve2_pkg::OP_MAC_AS: begin
                        act_scale_lo_q  <= rs1_i;
                        act_scale_hi_q  <= rs2_i;
                        act_scale_pulse <= 1'b1;
                    end
                    cve2_pkg::OP_MAC_WS: begin
                        weight_scale_lo_q  <= rs1_i;
                        weight_scale_hi_q  <= rs2_i;
                        weight_scale_pulse <= 1'b1;
                    end
                    default: ;
                endcase
            end

            // Capture the last VMAC return flag
            vmac_last_q <= (op_q == cve2_pkg::OP_VMAC) && data_rvalid_i && (count_q == (VL-1));

            // Assert snapshot valid delayed by 1 clock cycle
            if (vmac_last_q) begin
                snapshot_valid_q <= 1'b1;
            end
        end
    end

    always_comb begin
        state_d        = state_q;
        count_d        = count_q;
        acc_count_d    = acc_count_q;
        mem_req_sent_d = mem_req_sent_q;

        case (state_q)
            IDLE: begin
                count_d        = '0;
                acc_count_d    = '0;
                mem_req_sent_d = 1'b0;
                if (req_valid_i) begin
                    state_d = EXEC;
                end
            end
            EXEC: begin
                if ((op_q == cve2_pkg::OP_ZZ ) ||
                    (op_q == cve2_pkg::OP_MAC) ||
                    (op_q == cve2_pkg::OP_MVE) ||
                    (op_q == cve2_pkg::OP_MVO) ||
                    (op_q == cve2_pkg::OP_MV2) ||
                    (op_q == cve2_pkg::OP_MAC_AS)) begin
                    state_d = DONE;
                end 
                else if (op_q == cve2_pkg::OP_MAC_WS) begin
                    state_d = DONE;
                end 
                else if (op_q == cve2_pkg::OP_VMAC) begin
                    if (!mem_req_sent_q) begin
                        if (data_gnt_i) begin
                            mem_req_sent_d = 1'b1;
                        end
                    end else begin
                        if (data_rvalid_i) begin
                            mem_req_sent_d = 1'b0;
                            if (count_q == (VL-1)) begin
                                state_d = DONE;
                                count_d = '0;
                            end else begin
                                count_d = count_q + 1'b1;
                            end
                        end
                    end
                end
                //------------------------------------------------------------
                // Patched: MACACC execution FSM completion with Wait Sync
                //------------------------------------------------------------
                else if (op_q == cve2_pkg::OP_MACACC) begin
                    if (scale_busy_i) begin
                        state_d = WAIT_SCALE;
                    end else begin
                        if (acc_count_q == (ACC_VL-1)) begin
                            state_d     = DONE;
                            acc_count_d = '0;
                        end else begin
                            acc_count_d = acc_count_q + 1'b1;
                        end
                    end
                end
            end

            //------------------------------------------------------------
            // Patched: WAIT_SCALE handler logic
            //------------------------------------------------------------
            WAIT_SCALE: begin
                // Transition back to EXEC one clean cycle after scale_busy drops
                if (!scale_busy_i) begin
                    acc_count_d = '0;
                    state_d     = EXEC;
                end
            end

            DONE: begin
                state_d = IDLE;
            end
            default: begin
                state_d = IDLE;
            end
        endcase
    end

    always_comb begin
        req_ready_o    = 1'b0;
        busy_o         = 1'b1;
        done_o         = 1'b0;
        clear_o        = 1'b0;
        mv_en_o        = 1'b0;
        mv_mode_o      = MV_EVEN;
        scalar_we_o    = 1'b0;
        scalar_waddr_o = scalar_waddr_q;

        // Shared Activation logic
        mac_en_o = ((state_q == EXEC) && (op_q == cve2_pkg::OP_VMAC) && data_rvalid_i) || 
                   ((state_q == EXEC) && (op_q == cve2_pkg::OP_MAC));

        // Generate Accumulator Enable dynamically when in active EXEC state
        mac_acc_en_o = (state_q == EXEC) && (op_q == cve2_pkg::OP_MACACC);

        clear_o = (state_q == EXEC) && (op_q == cve2_pkg::OP_ZZ);

        mac_vrf_raddr_o = '0;
        mac_vrf_relem_o = '0;
        data_req_o   = 1'b0;
        data_addr_o  = '0;
        data_we_o    = 1'b0;
        data_be_o    = 4'b1111; 
        data_wdata_o = '0;

        act_scale_lo_o    = act_scale_lo_q;
        act_scale_hi_o    = act_scale_hi_q;
        weight_scale_lo_o = weight_scale_lo_q;
        weight_scale_hi_o = weight_scale_hi_q;

        act_scale_ready_o    = act_scale_pulse;
        weight_scale_ready_o = weight_scale_pulse;
        mac_snapshot_valid_o = snapshot_valid_q;

        case (state_q)
            IDLE: begin
                req_ready_o = 1'b1;
                busy_o      = 1'b0;
            end
            EXEC: begin
                unique case (op_q)
                    cve2_pkg::OP_MVE: begin
                        mv_en_o     = 1'b1;
                        mv_mode_o   = MV_EVEN;
                        scalar_we_o = 1'b1;
                    end
                    cve2_pkg::OP_MVO: begin
                        mv_en_o     = 1'b1;
                        mv_mode_o   = MV_ODD;
                        scalar_we_o = 1'b1;
                    end
                    cve2_pkg::OP_MV2: begin
                        mv_en_o     = 1'b1;
                        mv_mode_o   = MV_PAIR;
                        scalar_we_o = 1'b1;
                    end
                    default: ;
                endcase

                //------------------------------------------------------------
                // Patched: Shared VRF Addressing logic
                //------------------------------------------------------------
                if (op_q == cve2_pkg::OP_VMAC) begin
                    mac_vrf_raddr_o = mac_vrf_addr;
                    mac_vrf_relem_o = elem_idx;
                    if (!mem_req_sent_q) begin
                        data_req_o  = 1'b1;
                        data_addr_o = base_q + (count_q << 2); 
                    end
                end 
                else if (op_q == cve2_pkg::OP_MACACC) begin
                    // One vector register per MACACC
                    mac_vrf_raddr_o = bias_vs_q;
                    // Eight sequential 32-bit words
                    mac_vrf_relem_o = acc_count_q;
                end
            end
            
            WAIT_SCALE: begin
                // During wait, fetch addresses can stay default, bias remains inactive
                busy_o = 1'b1;
            end

            DONE: begin
                done_o = 1'b1;
            end
            default: ;
        endcase
    end

    genvar k;
    generate
        for (k = 0; k < TT; k++) begin : GEN_UNPACK_NIBBLES
            assign act_vector_o[k] =
                act_packed[4*k +: 4];

            assign weight_vector_o[k] =
                weight_packed[4*k +: 4];
        end
    endgenerate

    // print debug statement for VMAC
    always_ff @(posedge clk_i) begin
        if (rst_ni &&
            (op_q == cve2_pkg::OP_VMAC) &&
            data_rvalid_i) begin

            $display(
                "[%0t] [VMAC] vreg=v%0d elem=%0d flat=%0d vrf=%08x mem_addr=%08x weight=%08x mem_req=%0b mem_gnt=%0b mem_rvalid=%0b mac_en=%0b",
                $time,
                mac_vrf_addr,
                elem_idx,
                count_q,
                mac_vrf_rdata_i,
                base_q + (count_q << 2),
                data_rdata_i,
                mem_req_sent_q,
                data_gnt_i,
                data_rvalid_i,
                mac_en_o
            );
        end
    end

endmodule
