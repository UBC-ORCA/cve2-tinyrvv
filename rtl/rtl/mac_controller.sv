module mac_controller #(
    parameter int VL = 8 // Example parameter, adjust based on your design requirements
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
    //----------------------------------------------------------
    output logic                 mac_en_o,
    output logic                 clear_o,

    // --- [stev] ---
    input  logic [4:0]           vs1_i,
    input  logic [4:0]           weight_blk_i,
    input  logic [31:0]          base_i,

    output logic [4:0]           mac_vrf_raddr_o,
    output logic [2:0]           mac_vrf_relem_o,

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
    // --- [end] ---

    //----------------------------------------------------------
    // Operand interface
    //----------------------------------------------------------
    output logic [31:0]          act_data_o,
    output logic [31:0]          wt_data_o
);

    //----------------------------------------------------------
    // Registers & Internal Signals
    //----------------------------------------------------------
    // --- [stev] ---
    logic [4:0]  vs1_q;
    logic [4:0]  weight_blk_q;
    logic [31:0] base_q;

    // MEM Request Bookkeeping
    logic        mem_req_sent_q;
    logic        mem_req_sent_d;
    // --- [end] ---

    // Latched request signals
    cve2_pkg::mac_op_e op_q;
    logic [31:0]       rs1_q;
    logic [31:0]       rs2_q;

    // MAC cycle counter
    localparam int CNT_W = $clog2(VL);
    logic [CNT_W-1:0] count_q;
    logic [CNT_W-1:0] count_d;

    // FSM States
    typedef enum logic [1:0] {
        IDLE,
        EXEC,
        DONE
    } state_e;

    state_e state_q, state_d;

    //----------------------------------------------------------
    // Sequential Logic (Latches & State)
    //----------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            op_q           <= cve2_pkg::OP_ZZ;
            rs1_q          <= '0;
            rs2_q          <= '0;
            vs1_q          <= '0;
            weight_blk_q   <= '0; 
            base_q         <= '0; 
            state_q        <= IDLE;
            count_q        <= '0;
            mem_req_sent_q <= 1'b0;
        end else begin
            state_q        <= state_d;
            count_q        <= count_d;
            mem_req_sent_q <= mem_req_sent_d;

            if (req_valid_i && req_ready_o) begin
                op_q         <= cf_req_op_i;
                rs1_q        <= rs1_i;
                rs2_q        <= rs2_i;
                vs1_q        <= vs1_i;
                weight_blk_q <= weight_blk_i;
                base_q       <= base_i;
            end
        end
    end

    //----------------------------------------------------------
    // Next-State Logic
    //----------------------------------------------------------
    always_comb begin
        state_d        = state_q;
        count_d        = count_q;
        mem_req_sent_d = mem_req_sent_q;

        case (state_q)
            IDLE: begin
                count_d        = '0;
                mem_req_sent_d = 1'b0;
                if (req_valid_i) begin
                    state_d = EXEC;
                end
            end

            EXEC: begin
                if (!mem_req_sent_q) begin
                    // Phase 1: Waiting for the LSU to accept the address request
                    if (data_gnt_i) begin
                        mem_req_sent_d = 1'b1;
                    end
                end else begin
                    // Phase 2: Request accepted, waiting for valid return data
                    if (data_rvalid_i) begin
                        mem_req_sent_d = 1'b0; // Clear flag for next iteration

                        if (count_q == (VL-1)) begin
                            state_d = DONE;
                            count_d = '0;
                        end else begin
                            count_d = count_q + 1'b1;
                        end
                    end
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

    //----------------------------------------------------------
    // Combinational Control Generation
    //----------------------------------------------------------
    always_comb begin
        // Default Output Values
        req_ready_o  = 1'b0;
        busy_o       = 1'b1;
        done_o       = 1'b0;
        mac_en_o     = 1'b0;
        clear_o      = 1'b0;

        // Datapath Operands
        act_data_o   = rs1_q;
        wt_data_o    = data_rdata_i; // Driven safely by incoming memory data

        // VRF Control Defaults
        mac_vrf_raddr_o = '0;
        mac_vrf_relem_o = '0;

        // LSU Interface Defaults
        data_req_o   = 1'b0;
        data_addr_o  = '0;
        data_we_o    = 1'b0;
        data_be_o    = 4'b1111; // Standard word access byte-enable
        data_wdata_o = '0;

        case (state_q)
            IDLE: begin
                req_ready_o = 1'b1;
                busy_o      = 1'b0;
            end

            EXEC: begin
                if (op_q == cve2_pkg::OP_MAC) begin
                    // Continuously address the VRF throughout the transaction
                    mac_vrf_raddr_o = vs1_q;
                    mac_vrf_relem_o = count_q[2:0]; // Cast/match sizing if needed

                    // Assert memory request until granted
                    if (!mem_req_sent_q) begin
                        data_req_o  = 1'b1;
                        data_addr_o = base_q + (weight_blk_q << 2) + (count_q << 2);
                    end

                    // Fire the MAC Array strictly when the weight operand returns
                    mac_en_o = data_rvalid_i;
                end
            end

            DONE: begin
                done_o = 1'b1;
            end

            default: ;
        endcase
    end

// --- [stev] ---
always_ff @(posedge clk_i)
begin
    if(data_rvalid_i)
        $display(
        "[MAC_LOAD_RETURN] addr=%08x data=%08x count=%0d",
        data_addr_o,
        data_rdata_i,
        count_q);
end
// --- [end] ---

endmodule
