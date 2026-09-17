`timescale 1ns / 1ps

// Pattern 3: water-light warped diagonal moire in normalized logical space.
// P3-S2 is deliberately kept light: it is primarily x + registered warp.
module pattern_diagonal_moire (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    // S1: time-driven warp triangle. Period is 1.0 logical unit in y.
    wire [11:0] time_offset = logical_time[14:3];
    wire signed [16:0] warp_arg = $signed(logical_y) + $signed({5'd0, time_offset});
    wire [11:0] warp_phase = warp_arg[11:0];
    wire [10:0] warp_tri = warp_phase[11] ? ~warp_phase[10:0] : warp_phase[10:0];
    wire signed [11:0] warp_centered = $signed({1'b0, warp_tri}) - 12'sd1024;
    wire signed [11:0] warp_amount = warp_centered >>> 1; // about +/-0.125

    reg               valid_s1;
    reg signed [15:0] x_s1, y_s1;
    reg signed [11:0] warp_s1;
    reg [2:0]         color_phase_s1;

    always @(posedge clk) begin
        valid_s1       <= logical_valid;
        x_s1           <= logical_x;
        y_s1           <= logical_y;
        warp_s1        <= warp_amount;
        color_phase_s1 <= logical_time[14:12];
    end

    // S2: critical-path-conscious lightweight x + warp stage.
    wire signed [16:0] x_warp_comb = $signed(x_s1) + $signed(warp_s1);

    reg               valid_s2;
    reg signed [16:0] x_warp_s2;
    reg signed [15:0] y_s2;
    reg [2:0]         color_phase_s2;

    always @(posedge clk) begin
        valid_s2       <= valid_s1;
        x_warp_s2      <= x_warp_comb;
        y_s2           <= y_s1;
        color_phase_s2 <= color_phase_s1;
    end

    // S3: two opposite diagonal phase families, 0.5-unit wavelength.
    wire signed [17:0] diag_a = $signed(x_warp_s2) - $signed(y_s2);
    wire signed [17:0] diag_b = $signed(x_warp_s2) + $signed(y_s2);
    wire [10:0] phase_a = diag_a[10:0];
    wire [10:0] phase_b = diag_b[10:0];
    wire hit_a = (phase_a < 11'd160);
    wire hit_b = (phase_b < 11'd160);

    reg       valid_s3;
    reg       hit_a_s3, hit_b_s3;
    reg [2:0] color_a_s3, color_b_s3;
    reg [1:0] bg_s3;

    always @(posedge clk) begin
        valid_s3   <= valid_s2;
        hit_a_s3   <= hit_a;
        hit_b_s3   <= hit_b;
        color_a_s3 <= color_phase_s2;
        color_b_s3 <= color_phase_s2 + 3'd3;
        bg_s3      <= x_warp_s2[12:11] ^ y_s2[12:11];
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

    function [23:0] dark4;
        input [1:0] index;
        begin
            case (index)
                2'd0: dark4 = 24'h041C24;
                2'd1: dark4 = 24'h091638;
                2'd2: dark4 = 24'h210D32;
                default: dark4 = 24'h32101E;
            endcase
        end
    endfunction

    // S4: palette.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (hit_a_s3 && hit_b_s3)
            rgb888 <= 24'hF2F6FF;
        else if (hit_a_s3)
            rgb888 <= vivid8(color_a_s3);
        else if (hit_b_s3)
            rgb888 <= vivid8(color_b_s3);
        else
            rgb888 <= dark4(bg_s3);
    end

endmodule
