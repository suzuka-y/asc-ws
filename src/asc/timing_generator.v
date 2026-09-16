`timescale 1ns / 1ps

// Platform-independent real-display-space timing generator for ASC v0.41.
//
// This block owns the physical raster.  Pattern RTL must not consume h_count,
// v_count, sync timing, porch timing, or physical_x/physical_y directly.
module timing_generator (
    input  wire       clk,
    input  wire       reset_n,

    output reg  [9:0] h_count,
    output reg  [9:0] v_count,
    output wire [9:0] physical_x,
    output wire [9:0] physical_y,
    output wire       physical_valid,
    output wire       hsync,
    output wire       vsync,
    output wire       de,
    output wire       frame_tick
);

    localparam integer H_ACTIVE = 800;
    localparam integer H_FP     = 40;
    localparam integer H_SYNC   = 48;
    localparam integer H_BP     = 112;
    localparam integer H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP; // 1000

    localparam integer V_ACTIVE = 480;
    localparam integer V_FP     = 13;
    localparam integer V_SYNC   = 3;
    localparam integer V_BP     = 54;
    localparam integer V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP; // 550

    localparam integer H_SYNC_START = H_ACTIVE + H_FP;          // 840
    localparam integer H_SYNC_END   = H_ACTIVE + H_FP + H_SYNC; // 888
    localparam integer V_SYNC_START = V_ACTIVE + V_FP;          // 493
    localparam integer V_SYNC_END   = V_ACTIVE + V_FP + V_SYNC; // 496

    // Active-low reset: async assert, sync deassert via core_rst_n.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;
            if (v_count == V_TOTAL - 1)
                v_count <= 10'd0;
            else
                v_count <= v_count + 10'd1;
        end else begin
            h_count <= h_count + 10'd1;
        end
    end

    assign physical_x = h_count;
    assign physical_y = v_count;

    assign physical_valid = reset_n &&
                            (h_count < H_ACTIVE) &&
                            (v_count < V_ACTIVE);

    assign de = physical_valid;

    // Active-low sync. During reset both sync outputs remain inactive (High).
    assign hsync = !reset_n ? 1'b1 :
                   ~((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));

    assign vsync = !reset_n ? 1'b1 :
                   ~((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));

    // One-clock pulse during the final pixel-clock period of each frame.
    assign frame_tick = reset_n &&
                        (h_count == H_TOTAL - 1) &&
                        (v_count == V_TOTAL - 1);

endmodule
