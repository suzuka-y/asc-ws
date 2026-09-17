`timescale 1ns / 1ps

// Pattern 6: logical-cell hash mosaic.
module pattern_hash_mosaic (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    // S1: 0.125-unit square cell indices and slow logical-time epoch.
    wire signed [15:0] cell_x_full = $signed(logical_x) >>> 9;
    wire signed [15:0] cell_y_full = $signed(logical_y) >>> 9;
    wire [7:0] cx_comb = cell_x_full[7:0];
    wire [7:0] cy_comb = cell_y_full[7:0];
    wire [3:0] time_epoch_comb = logical_time[15:12];

    reg       valid_s1;
    reg [7:0] cx_s1, cy_s1;
    reg [3:0] time_s1;

    always @(posedge clk) begin
        valid_s1 <= logical_valid;
        cx_s1    <= cx_comb;
        cy_s1    <= cy_comb;
        time_s1  <= time_epoch_comb;
    end

    // S2: shift/add hash seed; arithmetic naturally wraps at 16 bits.
    wire [15:0] cx16 = {8'd0, cx_s1};
    wire [15:0] cy16 = {8'd0, cy_s1};
    wire [15:0] time16 = {12'd0, time_s1};
    wire [15:0] hash_a_comb = (cx16 << 1) + cx16 +
                               (cy16 << 2) + cy16 +
                               (time16 << 5) + 16'h1357;

    reg        valid_s2;
    reg [15:0] hash_a_s2;

    always @(posedge clk) begin
        valid_s2  <= valid_s1;
        hash_a_s2 <= hash_a_comb;
    end

    // S3: XOR whitening and palette index.
    wire [15:0] hash_b_comb = hash_a_s2 ^ (hash_a_s2 << 5) ^
                              (hash_a_s2 >> 3) ^ 16'hA53C;

    reg       valid_s3;
    reg [2:0] color_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        color_s3 <= hash_b_comb[2:0] ^ hash_b_comb[10:8];
    end

    function [23:0] vivid8;
        input [2:0] index;
        begin
            case (index)
                3'd0: vivid8 = 24'h00D9C7;
                3'd1: vivid8 = 24'h2F6BFF;
                3'd2: vivid8 = 24'h9B4DFF;
                3'd3: vivid8 = 24'hFF3D88;
                3'd4: vivid8 = 24'hFFAE2B;
                3'd5: vivid8 = 24'h42D65A;
                3'd6: vivid8 = 24'h00BDEB;
                default: vivid8 = 24'hE45CFF;
            endcase
        end
    endfunction

    // S4: full-cell palette output.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else
            rgb888 <= vivid8(color_s3);
    end

endmodule
