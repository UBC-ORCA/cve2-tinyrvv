`timescale 1ns/1ps

/******************************************************************************
 * mac_controller.sv
 *
 * Controller for MAC64 execution.
 *
 * Responsibilities:
 *
 *   - Accept decoded CF MAC instruction
 *   - Generate MAC array control
 *   - Count MAC cycles
 *   - Signal completion
 *
 * Does NOT handle:
 *   - scaling
 *   - snapshot
 *   - BF16 conversion
 *   - BRAM accumulation
 *
 ******************************************************************************/

module mac_controller #(

//    parameter int VL = 32
    parameter int VL = 8 //[stev] - test out two cycles 

)(
    input logic clk_i,
    input logic rst_ni,

    //----------------------------------------------------------
    // CF interface from cve2_cf_unit
    //----------------------------------------------------------

    input logic                  req_valid_i,
    input cve2_pkg::mac_op_e     cf_req_op_i,

    output logic                 req_ready_o,
    output logic                 busy_o,
    output logic                 done_o,

    //----------------------------------------------------------
    // Instruction operands
    //----------------------------------------------------------

    input logic [31:0] rs1_i,
    input logic [31:0] rs2_i,

    //----------------------------------------------------------
    // Control to MAC array
    //----------------------------------------------------------

    output logic                 mac_en_o,
    output logic                 clear_o,

// --- [stev] ---
    input logic [4:0] vs1_i,
    input logic [4:0] weight_blk_i,
    input logic [31:0] base_i,

output logic [4:0] mac_vrf_raddr_o,
output  logic [2:0]   mac_vrf_relem_o,

// --- [end] ---

    //----------------------------------------------------------
    // Operand interface
    //
    // Future: vector register / weight loader
    //----------------------------------------------------------

    output logic [31:0]          act_data_o,
    output logic [31:0]          wt_data_o
);

// --- [stev] ---

logic [4:0]  vs1_q;
logic [4:0]  weight_blk_q;
logic [31:0] base_q;
// --- [end] ---


    //----------------------------------------------------------
    // FSM
    //----------------------------------------------------------

    typedef enum logic [1:0] {

        IDLE,
        EXEC,
        DONE

    } state_e;

    state_e state_q;
    state_e state_d;

    //----------------------------------------------------------
    // Latched request
    //----------------------------------------------------------

    cve2_pkg::mac_op_e op_q;

    logic [31:0] rs1_q;
    logic [31:0] rs2_q;


    //----------------------------------------------------------
    // MAC cycle counter
    //----------------------------------------------------------

    localparam int CNT_W = $clog2(VL);

    logic [CNT_W-1:0] count_q;
    logic [CNT_W-1:0] count_d;


    //----------------------------------------------------------
    // Latch request
    //----------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin

        if(!rst_ni) begin
            op_q  <= cve2_pkg::OP_ZZ;
            rs1_q <= '0;
            rs2_q <= '0;
        end

        else if(req_valid_i && req_ready_o) begin
            op_q  <= cf_req_op_i;
            rs1_q <= rs1_i;
            rs2_q <= rs2_i;

// --- [stev] ---

	vs1_q <= vs1_i;
    weight_blk_q <= weight_blk_i;
    base_q       <= base_i;
// --- [end] ---

        end
    end

    //----------------------------------------------------------
    // FSM register
    //----------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin

        if(!rst_ni) begin
            state_q <= IDLE;
            count_q <= '0;
        end

        else begin
            state_q <= state_d;
            count_q <= count_d;
        end
    end



    //----------------------------------------------------------
    // FSM next state
    //----------------------------------------------------------

    always_comb begin


        state_d = state_q;
        count_d = count_q;


        case(state_q)
            IDLE:
            begin
                count_d = '0;

                if(req_valid_i)
                    state_d = EXEC;

            end

            EXEC:
            begin
                if(count_q == VL-1)
                begin
                    state_d = DONE;
                    count_d = '0;
                end

                else
                begin
                    count_d = count_q + 1'b1;
                end
            end

            DONE:
            begin
                state_d = IDLE;
            end

            default:
                state_d = IDLE;
        endcase

    end



    //----------------------------------------------------------
    // Control generation
    //----------------------------------------------------------

    always_comb begin

        req_ready_o = 0;
        busy_o = 1;
        done_o = 0;
        mac_en_o = 0;
        clear_o = 0;

        act_data_o = rs1_q;
        wt_data_o  = rs2_q;

// --- [stev] ---
mac_vrf_raddr_o = '0;
mac_vrf_relem_o = '0;
// --- [end] ---

        case(state_q)
            IDLE:
            begin
                req_ready_o = 1;
                busy_o = 0;
            end

            EXEC:
            begin
                //if(op_q == cve2_pkg::OP_MAC)
                if(op_q == cve2_pkg::OP_MAC) begin //[stev] - using the op_mac opcode
                    mac_en_o = 1;

			mac_vrf_raddr_o = vs1_q; //[stev] 
        		mac_vrf_relem_o = count_q;
		end
            end

            DONE:
            begin
                done_o = 1;
            end

        endcase

    end

endmodule
