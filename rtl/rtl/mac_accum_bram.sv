// Copyright (c) 2026
// SPDX-License-Identifier: Apache-2.0
//
// Structured coordinate-addressed Accumulator Tile BRAM module.
// Decoupled from physical addressing layers to preserve ISA abstractions.

module mac_accum_bram (
    input  logic        clk_i,
    input  logic        rst_ni,

    //----------------------------------
    // Read Port (Tile Structural Coordinates)
    //----------------------------------
    input  logic        rd_en_i,
    input  logic [4:0]  rd_tile_i,
    input  logic [2:0]  rd_row_i,
    input  logic [2:0]  rd_col_i,
    output logic [15:0] rd_data_o,

    //----------------------------------
    // Write Port (Tile Structural Coordinates)
    //----------------------------------
    input  logic        wr_en_i,
    input  logic [4:0]  wr_tile_i,
    input  logic [2:0]  wr_row_i,
    input  logic [2:0]  wr_col_i,
    input  logic [15:0] wr_data_i
);

    // Architectural Dimension Parameters
    localparam int unsigned NTILES = 32;
    localparam int unsigned TT     = 8;
    localparam int unsigned DEPTH  = NTILES * TT * TT; // 32 * 8 * 8 = 2048 entries
    localparam int unsigned ADDR_W = 11;

    // Accumulator Tile Memory Array
    // BRAM hint for Xilinx Vivado toolchain inference.
    (* ram_style = "block" *)
    logic [15:0] accum_mem [0:DEPTH-1];

    // Internal flattened physical addresses
    logic [ADDR_W-1:0] rd_addr_flat;
    logic [ADDR_W-1:0] wr_addr_flat;

    // Address translation pipeline logic: tile * 64 + row * 8 + col
    assign rd_addr_flat = (ADDR_W'(rd_tile_i) << 6) + (ADDR_W'(rd_row_i) << 3) + ADDR_W'(rd_col_i);
    assign wr_addr_flat = (ADDR_W'(wr_tile_i) << 6) + (ADDR_W'(wr_row_i) << 3) + ADDR_W'(wr_col_i);

    //----------------------------------
    // Tracking Variables for Latency Aligned Debugging
    //----------------------------------
    logic        rd_en_q;
    logic [4:0]  rd_tile_q;
    logic [2:0]  rd_row_q;
    logic [2:0]  rd_col_q;
    logic [ADDR_W-1:0] rd_addr_flat_q;

    //----------------------------------
    // Synchronous Read Process
    //----------------------------------
    always_ff @(posedge clk_i) begin
        if (rd_en_i) begin
            rd_data_o <= accum_mem[rd_addr_flat];
        end
        
        // Pipelining metadata to align log output with synchronous data arrival
        if (!rst_ni) begin
            rd_en_q        <= 1'b0;
            rd_tile_q      <= '0;
            rd_row_q       <= '0;
            rd_col_q       <= '0;
            rd_addr_flat_q <= '0;
        end else begin
            rd_en_q        <= rd_en_i;
            rd_tile_q      <= rd_tile_i;
            rd_row_q       <= rd_row_i;
            rd_col_q       <= rd_col_i;
            rd_addr_flat_q <= rd_addr_flat;
        end
    end

    //----------------------------------
    // Synchronous Write Process
    //----------------------------------
    always_ff @(posedge clk_i) begin
        if (wr_en_i) begin
            accum_mem[wr_addr_flat] <= wr_data_i;
        end
    end

    //----------------------------------
    // Simulation Debug Dumps
    //----------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_ni) begin
            // 1. Log Memory Array Read Accesses (Aligned to when rd_data_o updates)
            if (rd_en_q) begin
                $display("[BRAM_ACCUM_DEBUG] [%0t ns] MEMORY READ COMPLETE:", $time);
                $display("[BRAM_ACCUM_DEBUG]   Coordinates -> Tile=%2d | Row=%1d | Col=%1d", rd_tile_q, rd_row_q, rd_col_q);
                $display("[BRAM_ACCUM_DEBUG]   Addressing  -> Flat Physical Addr=11'd%0d (11'h%h)", rd_addr_flat_q, rd_addr_flat_q);
                $display("[BRAM_ACCUM_DEBUG]   Payload     -> Out Data=16'h%h (%5d signed)", rd_data_o, $signed(rd_data_o));
            end

            // 2. Log Memory Array Mutation Transactions
            if (wr_en_i) begin
                $display("[BRAM_ACCUM_DEBUG] [%0t ns] MEMORY WRITE TRANSACTION COMMITTED:", $time);
                $display("[BRAM_ACCUM_DEBUG]   Coordinates -> Tile=%2d | Row=%1d | Col=%1d", wr_tile_i, wr_row_i, wr_col_i);
                $display("[BRAM_ACCUM_DEBUG]   Addressing  -> Flat Physical Addr=11'd%0d (11'h%h)", wr_addr_flat, wr_addr_flat);
                $display("[BRAM_ACCUM_DEBUG]   Payload     -> In Data =16'h%h (%5d signed)", wr_data_i, $signed(wr_data_i));
            end
        end
    end

//accum_mem
integer r,c;
integer addr;

always_ff @(posedge clk_i) begin
    //if (rst_ni && wr_en_i) begin
        $display("");
        $display("======================================================");
//        $display("ACCUMULATOR BRAM TILE %0d @ time %0t", wr_tile_i, $time);
        $display("ACCUMULATOR BRAM TILE 0 @ time %0t", $time);


        for (r = 0; r < TT; r++) begin
            $write("Row %0d :", r);

            for (c = 0; c < TT; c++) begin
                addr = (0 << 6) + (r << 3) + c;
                $write(" %6h", accum_mem[addr]);
            end

            $write("\n");
        end

        $display("======================================================");
        $display("");
// $display("");
  //      $display("======================================================");
//        $display("ACCUMULATOR BRAM TILE %0d @ time %0t", wr_tile_i, $time);
//        $display("ACCUMULATOR BRAM TILE 1 @ time %0t", $time);


//        for (r = 0; r < TT; r++) begin
 //           $write("Row %0d :", r);

  //          for (c = 0; c < TT; c++) begin
  //              addr = (1 << 6) + (r << 3) + c;
   //             $write(" %6h", accum_mem[addr]);
  //          end
//
  //          $write("\n");
  //      end

  // //     $display("======================================================");
 //       $display("");
// $display("");
 //       $display("======================================================");
//        $display("ACCUMULATOR BRAM TILE %0d @ time %0t", wr_tile_i, $time);
  //      $display("ACCUMULATOR BRAM TILE 31 @ time %0t", $time);


   //     for (r = 0; r < TT; r++) begin
  //          $write("Row %0d :", r);

 //           for (c = 0; c < TT; c++) begin
 //               addr = (31 << 6) + (r << 3) + c;
  //              $write(" %6h", accum_mem[addr]);
  //          end

  //          $write("\n");
   //     end

   //     $display("======================================================");
    //    $display("");


    //end
end

endmodule
