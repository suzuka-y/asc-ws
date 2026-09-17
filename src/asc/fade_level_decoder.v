`timescale 1ns / 1ps

// ASC v0.42 fade-level decoder.
// Decode is intentionally performed before the RGB fade stage so the
// comparator chain is removed from the fade-scaling critical path.
module fade_level_decoder (
    input  wire [9:0] scene_frame_count,
    output reg  [3:0] fade_level
);

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

endmodule
