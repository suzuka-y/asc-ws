`timescale 1ns / 1ps

// Pattern 6: 32x32 square-cell hash mosaic.
// ASC v0.41 timing contract: exactly 4 pixel-clock latency.
module pattern_hash_mosaic (
    input  wire        clk,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    // P6-S1: coefficient products using shift/add only.
    wire [4:0] i = logical_x[9:5];
    wire [4:0] j = logical_y[9:5];
    wire [4:0] t6 = frame_phase[8:4];
    wire [15:0] i16 = {11'd0, i};
    wire [15:0] j16 = {11'd0, j};
    wire [15:0] t16 = {11'd0, t6};
    wire [15:0] i37_comb = (i16 << 5) + (i16 << 2) + i16;
    wire [15:0] j73_comb = (j16 << 6) + (j16 << 3) + j16;
    wire [15:0] t29_comb = (t16 << 4) + (t16 << 3) + (t16 << 2) + t16;

    reg        valid_s1;
    reg [15:0] i37_s1, j73_s1, t29_s1;
    reg        parity_s1;

    always @(posedge clk) begin
        valid_s1 <= logical_valid;
        i37_s1 <= i37_comb;
        j73_s1 <= j73_comb;
        t29_s1 <= t29_comb;
        parity_s1 <= i[0] ^ j[0];
    end

    // P6-S2: first two hash-mixing operations.
    wire [15:0] h0_comb = i37_s1 ^ j73_s1 ^ t29_s1;
    wire [15:0] h1_comb = h0_comb ^ (h0_comb >> 3);

    reg        valid_s2;
    reg [15:0] h1_s2;
    reg        parity_s2;

    always @(posedge clk) begin
        valid_s2 <= valid_s1;
        h1_s2 <= h1_comb;
        parity_s2 <= parity_s1;
    end

    // P6-S3: remaining hash mixing and palette index.
    wire [15:0] h2_comb = h1_s2 ^ (h1_s2 << 5);
    wire [15:0] h_comb  = h2_comb ^ (h2_comb >> 7);
    wire [2:0] q6_comb = {parity_s2, h_comb[1:0]};

    reg       valid_s3;
    reg [2:0] q6_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        q6_s3 <= q6_comb;
    end

    function [23:0] vivid8_color;
        input [2:0] index;
        begin
            case (index)
                3'd0: vivid8_color = 24'h00D9C7;
                3'd1: vivid8_color = 24'h2F6BFF;
                3'd2: vivid8_color = 24'h9B4DFF;
                3'd3: vivid8_color = 24'hFF3D88;
                3'd4: vivid8_color = 24'hFFAE2B;
                3'd5: vivid8_color = 24'h42D65A;
                3'd6: vivid8_color = 24'h00BDEB;
                default: vivid8_color = 24'hE45CFF;
            endcase
        end
    endfunction

    // P6-S4: palette lookup / output register.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else
            rgb888 <= vivid8_color(q6_s3);
    end

endmodule
