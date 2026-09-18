`timescale 1ns / 1ps

// ASC v0.43 scene controller.
// One scene lasts 600 frames = 10 seconds at 60 Hz.
module scene_controller (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       frame_tick,

    output reg  [9:0] scene_frame_count,
    output reg  [7:0] pattern_mask,
    output reg  [1:0] mix_shift
);

    localparam [7:0] SCENE_SEED = 8'h5A;
    localparam [7:0] SCENE_STEP = 8'h57;

    reg [7:0] candidate_state;
    reg [7:0] next_pattern_mask;
    reg [1:0] next_mix_shift;
    reg       next_valid;

    wire [3:0] candidate_popcount;
    wire       candidate_legal;
    wire [1:0] candidate_mix_shift;

    function [3:0] popcount8;
        input [7:0] value;
        integer i;
        begin
            popcount8 = 4'd0;
            for (i = 0; i < 8; i = i + 1)
                popcount8 = popcount8 + value[i];
        end
    endfunction

    assign candidate_popcount = popcount8(candidate_state);
    assign candidate_legal = (candidate_popcount == 4'd1) ||
                             (candidate_popcount == 4'd2) ||
                             (candidate_popcount == 4'd4) ||
                             (candidate_popcount == 4'd8);
    assign candidate_mix_shift = (candidate_popcount == 4'd1) ? 2'd0 :
                                 (candidate_popcount == 4'd2) ? 2'd1 :
                                 (candidate_popcount == 4'd4) ? 2'd2 : 2'd3;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scene_frame_count <= 10'd0;
            pattern_mask      <= SCENE_SEED;
            mix_shift         <= 2'd2;
            candidate_state   <= SCENE_SEED + SCENE_STEP;
            next_pattern_mask <= 8'd0;
            next_mix_shift    <= 2'd0;
            next_valid        <= 1'b0;
        end else begin
            if (!next_valid) begin
                candidate_state <= candidate_state + SCENE_STEP;
                if (candidate_legal) begin
                    next_pattern_mask <= candidate_state;
                    next_mix_shift    <= candidate_mix_shift;
                    next_valid        <= 1'b1;
                end
            end

            if (frame_tick) begin
                if (scene_frame_count < 10'd599) begin
                    scene_frame_count <= scene_frame_count + 10'd1;
                end else begin
                    scene_frame_count <= 10'd0;
                    if (next_valid) begin
                        pattern_mask <= next_pattern_mask;
                        mix_shift    <= next_mix_shift;
                        next_valid   <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
