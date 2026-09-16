`timescale 1ns / 1ps

// Pattern 3: water-light warped diagonal moire.
// ASC v0.41 timing contract: exactly 4 pixel-clock latency.
//
// v0.41 redistributes the v0.4 P3-S1 -> P3-S2 critical path:
//   S1 now performs the temporal triangle, y+time warp triangle,
//   centering and arithmetic shift.
//   S2 is reduced primarily to the signed x + warp addition.
// The arithmetic is unchanged, so the visible result remains bit-exact.
module pattern_diagonal_moire (
    input  wire        clk,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    // ------------------------------------------------------------------
    // P3-S1: temporal triangle + spatial warp amount.
    // This intentionally absorbs the heavy pre-warp operations that were
    // previously concentrated in P3-S2.
    // ------------------------------------------------------------------
    wire [9:0] frame_tri_ext_comb = frame_phase[8] ?
        (10'd512 - {1'b0, frame_phase}) : {1'b0, frame_phase};
    wire [8:0] frame_tri_comb = frame_tri_ext_comb[8:0];
    wire [7:0] warp_time_comb = frame_tri_comb[8:1];

    wire [8:0] warp_r_comb = logical_y[8:0] + {1'b0, warp_time_comb};
    wire [8:0] warp_tri_comb = warp_r_comb[8] ?
        (10'd512 - {1'b0, warp_r_comb}) : warp_r_comb;
    wire signed [9:0] warp_centered_comb =
        $signed({1'b0, warp_tri_comb}) - 10'sd128;
    wire signed [9:0] warp_comb = warp_centered_comb >>> 2;

    reg               valid_s1;
    reg [9:0]         x_s1;
    reg [9:0]         y_s1;
    reg [8:0]         phase_s1;
    reg [7:0]         warp_time_s1;
    reg signed [9:0]  warp_s1;

    always @(posedge clk) begin
        valid_s1     <= logical_valid;
        x_s1         <= logical_x;
        y_s1         <= logical_y;
        phase_s1     <= frame_phase;
        warp_time_s1 <= warp_time_comb;
        warp_s1      <= warp_comb;
    end

    // ------------------------------------------------------------------
    // P3-S2: warped x coordinate only. This is the path shortened in v0.41.
    // ------------------------------------------------------------------
    wire signed [11:0] x_warped_comb =
        $signed({2'b00, x_s1}) + {{2{warp_s1[9]}}, warp_s1};

    reg               valid_s2;
    reg signed [11:0] x_warped_s2;
    reg [9:0]         y_s2;
    reg [8:0]         phase_s2;
    reg [7:0]         warp_time_s2;

    always @(posedge clk) begin
        valid_s2     <= valid_s1;
        x_warped_s2  <= x_warped_comb;
        y_s2         <= y_s1;
        phase_s2     <= phase_s1;
        warp_time_s2 <= warp_time_s1;
    end

    // ------------------------------------------------------------------
    // P3-S3: stripe family / background classification.
    // ------------------------------------------------------------------
    wire signed [12:0] a_full = {{1{x_warped_s2[11]}}, x_warped_s2} -
                                  $signed({3'b000, y_s2}) +
                                  $signed({4'b0000, phase_s2});
    wire signed [12:0] b_full = {{1{x_warped_s2[11]}}, x_warped_s2} +
                                  $signed({3'b000, y_s2}) -
                                  $signed({4'b0000, phase_s2});
    wire [6:0] a_mod = a_full[6:0];
    wire [6:0] b_mod = b_full[6:0];
    wire [6:0] da = a_mod[6] ? (8'd128 - {1'b0, a_mod}) : a_mod;
    wire [6:0] db = b_mod[6] ? (8'd128 - {1'b0, b_mod}) : b_mod;

    wire signed [12:0] bg_full = {{1{x_warped_s2[11]}}, x_warped_s2} -
                                   $signed({3'b000, y_s2}) +
                                   $signed({5'b00000, warp_time_s2});

    reg       valid_s3;
    reg       ma_s3;
    reg       mb_s3;
    reg [1:0] bg_index_s3;

    always @(posedge clk) begin
        valid_s3    <= valid_s2;
        ma_s3       <= (da < 7'd10);
        mb_s3       <= (db < 7'd10);
        bg_index_s3 <= bg_full[8:7];
    end

    function [23:0] bg3_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: bg3_color = 24'h041C24;
                2'd1: bg3_color = 24'h091638;
                2'd2: bg3_color = 24'h210D32;
                default: bg3_color = 24'h32101E;
            endcase
        end
    endfunction

    // P3-S4: palette selection / output register.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (ma_s3 && mb_s3)
            rgb888 <= 24'hFF3D88;
        else if (ma_s3)
            rgb888 <= 24'h00D9C7;
        else if (mb_s3)
            rgb888 <= 24'h2F6BFF;
        else
            rgb888 <= bg3_color(bg_index_s3);
    end

endmodule
