`timescale 1ns / 1ps

// Platform-independent ASC v0.41 scene controller.
//
// - One scene lasts 600 frames.
// - The current scene is represented directly by pattern_mask[7:0].
// - SCENE_SEED is loaded once at reset and is not updated during operation.
// - Candidate masks advance by a fixed odd SCENE_STEP modulo 256.
// - Only masks with popcount 1, 2, 4, or 8 are accepted.
// - The next legal scene is precomputed while the current scene is displayed.
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
                                 (candidate_popcount == 4'd4) ? 2'd2 :
                                                               2'd3;

    // Active-low reset: async assert, sync deassert via core_rst_n.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scene_frame_count <= 10'd0;
            pattern_mask      <= SCENE_SEED;
            mix_shift         <= 2'd2;  // popcount(8'h5A) = 4

            // First candidate after the seed: 8'h5A + 8'h57 = 8'hB1.
            candidate_state   <= SCENE_SEED + SCENE_STEP;
            next_pattern_mask <= 8'd0;
            next_mix_shift    <= 2'd0;
            next_valid        <= 1'b0;
        end else begin
            // Search one candidate per pixel clock until the next legal scene
            // has been found. Candidate state always advances after evaluation.
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

                    // Under normal operation next_valid is asserted many clocks
                    // before this boundary. If it is not, keep the current scene.
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
