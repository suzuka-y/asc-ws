`timescale 1ns / 1ps

// Nine-level, shift/add-only fade scaler.
// ASC v0.4 timing contract: exactly 1 pixel-clock latency.
module fade_scaler (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [9:0]  scene_frame_count,
    input  wire [23:0] mixed_rgb888,
    output reg  [23:0] faded_rgb888
);

    reg [3:0] fade_level;

    always @* begin
        if (scene_frame_count <= 10'd6)
            fade_level = 4'd0;
        else if (scene_frame_count <= 10'd13)
            fade_level = 4'd1;
        else if (scene_frame_count <= 10'd20)
            fade_level = 4'd2;
        else if (scene_frame_count <= 10'd27)
            fade_level = 4'd3;
        else if (scene_frame_count <= 10'd34)
            fade_level = 4'd4;
        else if (scene_frame_count <= 10'd41)
            fade_level = 4'd5;
        else if (scene_frame_count <= 10'd48)
            fade_level = 4'd6;
        else if (scene_frame_count <= 10'd55)
            fade_level = 4'd7;
        else if (scene_frame_count <= 10'd543)
            fade_level = 4'd8;
        else if (scene_frame_count <= 10'd550)
            fade_level = 4'd7;
        else if (scene_frame_count <= 10'd557)
            fade_level = 4'd6;
        else if (scene_frame_count <= 10'd564)
            fade_level = 4'd5;
        else if (scene_frame_count <= 10'd571)
            fade_level = 4'd4;
        else if (scene_frame_count <= 10'd578)
            fade_level = 4'd3;
        else if (scene_frame_count <= 10'd585)
            fade_level = 4'd2;
        else if (scene_frame_count <= 10'd592)
            fade_level = 4'd1;
        else
            fade_level = 4'd0;
    end

    function [7:0] scale_channel;
        input [7:0] c;
        input [3:0] level;
        begin
            case (level)
                4'd0:    scale_channel = 8'd0;
                4'd1:    scale_channel = c >> 4;
                4'd2:    scale_channel = c >> 3;
                4'd3:    scale_channel = (c >> 3) + (c >> 4);
                4'd4:    scale_channel = c >> 2;
                4'd5:    scale_channel = (c >> 2) + (c >> 3);
                4'd6:    scale_channel = c >> 1;
                4'd7:    scale_channel = (c >> 1) + (c >> 2);
                default: scale_channel = c;
            endcase
        end
    endfunction

    wire [7:0] faded_r_comb = scale_channel(mixed_rgb888[23:16], fade_level);
    wire [7:0] faded_g_comb = scale_channel(mixed_rgb888[15:8],  fade_level);
    wire [7:0] faded_b_comb = scale_channel(mixed_rgb888[7:0],   fade_level);

    always @(posedge clk) begin
        if (!reset_n)
            faded_rgb888 <= 24'h000000;
        else
            faded_rgb888 <= {faded_r_comb, faded_g_comb, faded_b_comb};
    end

endmodule
