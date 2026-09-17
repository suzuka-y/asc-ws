`timescale 1ns / 1ps

// ASC v0.42 physical raster timing generator.
// 1280x720p60, 74.25 MHz pixel clock, positive HSYNC/VSYNC.
// Pattern RTL must not consume h_count/v_count/physical_x/physical_y directly.
module timing_generator (
    input  wire        clk,
    input  wire        reset_n,

    output reg  [10:0] h_count,
    output reg  [9:0]  v_count,
    output wire [10:0] physical_x,
    output wire [9:0]  physical_y,
    output wire        physical_valid,
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

    localparam integer H_SYNC_START = H_ACTIVE + H_FP;          // 1390
    localparam integer H_SYNC_END   = H_SYNC_START + H_SYNC;    // 1430
    localparam integer V_SYNC_START = V_ACTIVE + V_FP;          // 725
    localparam integer V_SYNC_END   = V_SYNC_START + V_SYNC;    // 730

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            h_count <= 11'd0;
            v_count <= 10'd0;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= 11'd0;
            if (v_count == V_TOTAL - 1)
                v_count <= 10'd0;
            else
                v_count <= v_count + 10'd1;
        end else begin
            h_count <= h_count + 11'd1;
        end
    end

    assign physical_x = h_count;
    assign physical_y = v_count;

    assign physical_valid = reset_n &&
                            (h_count < H_ACTIVE) &&
                            (v_count < V_ACTIVE);
    assign de = physical_valid;

    // Positive sync polarity. During reset both syncs stay inactive Low.
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
