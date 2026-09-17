`timescale 1ns / 1ps

// Pattern 8: pulse columns defined entirely in logical space/time.
module pattern_pulse_columns (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    // S1: 0.125-unit columns, local x mask, per-column time phase.
    wire signed [15:0] col_full = $signed(logical_x) >>> 9;
    wire [7:0] col_comb = col_full[7:0];
    wire [8:0] local_x_comb = logical_x[8:0];
    wire x_hit_comb = (local_x_comb >= 9'd96) && (local_x_comb < 9'd416);
    wire [7:0] three_col = {1'b0, col_comb[6:0]} +
                           ({1'b0, col_comb[6:0]} << 1);
    wire [5:0] phase_comb = logical_time[11:6] + three_col[5:0];
    wire [2:0] color_comb = col_comb[2:0] + logical_time[14:12];

    reg               valid_s1;
    reg               x_hit_s1;
    reg [5:0]         phase_s1;
    reg signed [15:0] y_s1;
    reg [2:0]         color_s1;

    always @(posedge clk) begin
        valid_s1 <= logical_valid;
        x_hit_s1 <= x_hit_comb;
        phase_s1 <= phase_comb;
        y_s1     <= logical_y;
        color_s1 <= color_comb;
    end

    // S2: 0..1.0 logical height triangle and bottom-origin threshold.
    wire [5:0] tri_comb = (phase_s1 <= 6'd32) ? phase_s1 : (6'd64 - phase_s1);
    wire [12:0] height_comb = {7'd0, tri_comb} << 7; // max 4096 == 1.0
    wire signed [15:0] threshold_comb = 16'sd4096 - $signed({3'd0, height_comb});

    reg               valid_s2;
    reg               x_hit_s2;
    reg signed [15:0] y_s2;
    reg signed [15:0] threshold_s2;
    reg [2:0]         color_s2;

    always @(posedge clk) begin
        valid_s2     <= valid_s1;
        x_hit_s2     <= x_hit_s1;
        y_s2         <= y_s1;
        threshold_s2 <= threshold_comb;
        color_s2     <= color_s1;
    end

    // S3: final logical geometry hit.
    reg       valid_s3;
    reg       hit_s3;
    reg [2:0] color_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        hit_s3   <= x_hit_s2 && ($signed(y_s2) >= $signed(threshold_s2));
        color_s3 <= color_s2;
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

    // S4: palette / black background.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (hit_s3)
            rgb888 <= vivid8(color_s3);
        else
            rgb888 <= 24'h000000;
    end

endmodule
