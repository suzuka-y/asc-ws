`timescale 1ns / 1ps

// Pattern 4: three broad high-saturation wave bands.
// ASC v0.4 timing contract: exactly 4 pixel-clock latency.
module pattern_broad_wave_bands (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    // P4-S1: modulo coordinates for the two triangle-wave families.
    wire [7:0] two_f_mod256 = {frame_phase[6:0], 1'b0};
    wire [7:0] r10_comb = logical_x[7:0] + two_f_mod256;
    wire [7:0] r11_comb = logical_x[7:0] + two_f_mod256 + 8'd61;
    wire [7:0] r12_comb = logical_x[7:0] + two_f_mod256 + 8'd122;
    wire [6:0] r20_comb = logical_x[7:1] - frame_phase[6:0];
    wire [6:0] r21_comb = logical_x[7:1] - frame_phase[6:0] + 7'd37;
    wire [6:0] r22_comb = logical_x[7:1] - frame_phase[6:0] + 7'd74;

    reg       valid_s1;
    reg [7:0] r10_s1, r11_s1, r12_s1;
    reg [6:0] r20_s1, r21_s1, r22_s1;
    reg [9:0] y_s1;
    reg [1:0] bg_index_s1;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s1 <= 1'b0;
            r10_s1 <= 8'd0; r11_s1 <= 8'd0; r12_s1 <= 8'd0;
            r20_s1 <= 7'd0; r21_s1 <= 7'd0; r22_s1 <= 7'd0;
            y_s1 <= 10'd0;
            bg_index_s1 <= 2'd0;
        end else begin
            valid_s1 <= logical_valid;
            r10_s1 <= r10_comb; r11_s1 <= r11_comb; r12_s1 <= r12_comb;
            r20_s1 <= r20_comb; r21_s1 <= r21_comb; r22_s1 <= r22_comb;
            y_s1 <= logical_y;
            bg_index_s1 <= logical_y[8:7];
        end
    end

    // P4-S2: triangle waves and resulting band centers.
    wire [7:0] t10 = r10_s1[7] ? (9'd256 - {1'b0, r10_s1}) : r10_s1;
    wire [7:0] t11 = r11_s1[7] ? (9'd256 - {1'b0, r11_s1}) : r11_s1;
    wire [7:0] t12 = r12_s1[7] ? (9'd256 - {1'b0, r12_s1}) : r12_s1;
    wire signed [8:0] u0 = $signed({1'b0, t10}) - 9'sd64;
    wire signed [8:0] u1 = $signed({1'b0, t11}) - 9'sd64;
    wire signed [8:0] u2 = $signed({1'b0, t12}) - 9'sd64;

    wire [6:0] t20 = r20_s1[6] ? (8'd128 - {1'b0, r20_s1}) : r20_s1;
    wire [6:0] t21 = r21_s1[6] ? (8'd128 - {1'b0, r21_s1}) : r21_s1;
    wire [6:0] t22 = r22_s1[6] ? (8'd128 - {1'b0, r22_s1}) : r22_s1;
    wire signed [7:0] v0 = $signed({1'b0, t20}) - 8'sd32;
    wire signed [7:0] v1 = $signed({1'b0, t21}) - 8'sd32;
    wire signed [7:0] v2 = $signed({1'b0, t22}) - 8'sd32;

    wire signed [10:0] c0_comb = 11'sd92  + (u0 >>> 1) + (v0 >>> 1);
    wire signed [10:0] c1_comb = 11'sd240 + (u1 >>> 1) + (v1 >>> 1);
    wire signed [10:0] c2_comb = 11'sd385 + (u2 >>> 1) + (v2 >>> 1);

    reg               valid_s2;
    reg signed [10:0] c0_s2, c1_s2, c2_s2;
    reg [9:0]         y_s2;
    reg [1:0]         bg_index_s2;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s2 <= 1'b0;
            c0_s2 <= 11'sd0; c1_s2 <= 11'sd0; c2_s2 <= 11'sd0;
            y_s2 <= 10'd0;
            bg_index_s2 <= 2'd0;
        end else begin
            valid_s2 <= valid_s1;
            c0_s2 <= c0_comb; c1_s2 <= c1_comb; c2_s2 <= c2_comb;
            y_s2 <= y_s1;
            bg_index_s2 <= bg_index_s1;
        end
    end

    // P4-S3: distance-to-band comparisons.
    wire signed [11:0] dy0 = $signed({2'b00, y_s2}) - {{1{c0_s2[10]}}, c0_s2};
    wire signed [11:0] dy1 = $signed({2'b00, y_s2}) - {{1{c1_s2[10]}}, c1_s2};
    wire signed [11:0] dy2 = $signed({2'b00, y_s2}) - {{1{c2_s2[10]}}, c2_s2};
    wire [10:0] ady0 = dy0[11] ? -dy0 : dy0;
    wire [10:0] ady1 = dy1[11] ? -dy1 : dy1;
    wire [10:0] ady2 = dy2[11] ? -dy2 : dy2;

    reg       valid_s3;
    reg       m0_s3, m1_s3, m2_s3;
    reg [1:0] bg_index_s3;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s3 <= 1'b0;
            m0_s3 <= 1'b0; m1_s3 <= 1'b0; m2_s3 <= 1'b0;
            bg_index_s3 <= 2'd0;
        end else begin
            valid_s3 <= valid_s2;
            m0_s3 <= (ady0 < 11'd42);
            m1_s3 <= (ady1 < 11'd42);
            m2_s3 <= (ady2 < 11'd42);
            bg_index_s3 <= bg_index_s2;
        end
    end

    function [23:0] bg4_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: bg4_color = 24'h041C24;
                2'd1: bg4_color = 24'h091638;
                2'd2: bg4_color = 24'h210D32;
                default: bg4_color = 24'h32101E;
            endcase
        end
    endfunction

    // P4-S4: priority color select / output register.
    always @(posedge clk) begin
        if (!reset_n || !valid_s3)
            rgb888 <= 24'h000000;
        else if (m0_s3)
            rgb888 <= 24'h00D9C7;
        else if (m1_s3)
            rgb888 <= 24'h9B4DFF;
        else if (m2_s3)
            rgb888 <= 24'hFF3D88;
        else
            rgb888 <= bg4_color(bg_index_s3);
    end

endmodule
