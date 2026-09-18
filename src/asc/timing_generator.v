`timescale 1ns / 1ps

// ASC v0.43 physical raster timing + fixed 16x9 artwork grid.
//
// Physical profile is intentionally fixed for the tapeout artwork:
//   1280x720p60, 74.25 MHz, positive HSYNC/VSYNC.
//
// The pattern grid is also physical for v0.43:
//   16 x 9 cells, each 80 x 80 physical pixels.
// A 40-pixel vertical row coordinate is additionally exported for the
// staggered brick pattern.  These grid counters are generated incrementally;
// no divider or modulo operator is used in the pixel path.
module timing_generator (
    input  wire        clk,
    input  wire        reset_n,

    output reg  [10:0] h_count,
    output reg  [9:0]  v_count,
    output wire [10:0] physical_x,
    output wire [9:0]  physical_y,
    output wire        physical_valid,

    output reg  [3:0]  cell_x80,
    output reg  [6:0]  local_x80,
    output reg  [3:0]  cell_y80,
    output reg  [6:0]  local_y80,
    output reg  [4:0]  row_y40,
    output reg  [5:0]  local_y40,

    output wire        hsync,
    output wire        vsync,
    output wire        de,
    output wire        frame_tick
);

    localparam integer H_ACTIVE = 1280;
    localparam integer H_FP     = 110;
    localparam integer H_SYNC   = 40;
    localparam integer H_BP     = 220;
    localparam integer H_TOTAL  = 1650;

    localparam integer V_ACTIVE = 720;
    localparam integer V_FP     = 5;
    localparam integer V_SYNC   = 5;
    localparam integer V_BP     = 20;
    localparam integer V_TOTAL  = 750;

    localparam integer H_SYNC_START = H_ACTIVE + H_FP;
    localparam integer H_SYNC_END   = H_SYNC_START + H_SYNC;
    localparam integer V_SYNC_START = V_ACTIVE + V_FP;
    localparam integer V_SYNC_END   = V_SYNC_START + V_SYNC;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            h_count    <= 11'd0;
            v_count    <= 10'd0;
            cell_x80   <= 4'd0;
            local_x80  <= 7'd0;
            cell_y80   <= 4'd0;
            local_y80  <= 7'd0;
            row_y40    <= 5'd0;
            local_y40  <= 6'd0;
        end else begin
            // ----------------------------------------------------------
            // Raster counters.
            // ----------------------------------------------------------
            if (h_count == H_TOTAL - 1) begin
                h_count <= 11'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 11'd1;
            end

            // ----------------------------------------------------------
            // X grid: 80 pixels/cell, exactly 16 cells across 1280 px.
            // Values during horizontal blanking are don't-care, so reset
            // immediately after the last active pixel.
            // ----------------------------------------------------------
            if (h_count == H_ACTIVE - 1 || h_count == H_TOTAL - 1) begin
                cell_x80  <= 4'd0;
                local_x80 <= 7'd0;
            end else if (h_count < H_ACTIVE - 1) begin
                if (local_x80 == 7'd79) begin
                    local_x80 <= 7'd0;
                    cell_x80  <= cell_x80 + 4'd1;
                end else begin
                    local_x80 <= local_x80 + 7'd1;
                end
            end

            // ----------------------------------------------------------
            // Y grids advance once per raster line.
            // 80-pixel cells -> 9 rows.
            // 40-pixel rows  -> 18 rows, used by the brick pattern.
            // ----------------------------------------------------------
            if (h_count == H_TOTAL - 1) begin
                if (v_count == V_TOTAL - 1 || v_count == V_ACTIVE - 1) begin
                    cell_y80  <= 4'd0;
                    local_y80 <= 7'd0;
                    row_y40   <= 5'd0;
                    local_y40 <= 6'd0;
                end else if (v_count < V_ACTIVE - 1) begin
                    if (local_y80 == 7'd79) begin
                        local_y80 <= 7'd0;
                        cell_y80  <= cell_y80 + 4'd1;
                    end else begin
                        local_y80 <= local_y80 + 7'd1;
                    end

                    if (local_y40 == 6'd39) begin
                        local_y40 <= 6'd0;
                        row_y40   <= row_y40 + 5'd1;
                    end else begin
                        local_y40 <= local_y40 + 6'd1;
                    end
                end
            end
        end
    end

    assign physical_x = h_count;
    assign physical_y = v_count;

    assign physical_valid = reset_n &&
                            (h_count < H_ACTIVE) &&
                            (v_count < V_ACTIVE);
    assign de = physical_valid;

    assign hsync = reset_n &&
                   (h_count >= H_SYNC_START) &&
                   (h_count <  H_SYNC_END);

    assign vsync = reset_n &&
                   (v_count >= V_SYNC_START) &&
                   (v_count <  V_SYNC_END);

    assign frame_tick = reset_n &&
                        (h_count == H_TOTAL - 1) &&
                        (v_count == V_TOTAL - 1);

endmodule
