`timescale 1ns / 1ps

// Pattern 4: three broad, slowly waving color bands.
module pattern_broad_wave_bands (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    function signed [12:0] triangle_centered;
        input [11:0] phase;
        reg [10:0] tri_val;
        begin
            tri_val = phase[11] ? ~phase[10:0] : phase[10:0];
            triangle_centered = $signed({1'b0, tri_val}) - 13'sd1024;
        end
    endfunction

    // S1: two low-frequency triangles from logical x/time.
    wire [11:0] t_fast = logical_time[14:3];
    wire [11:0] t_slow = logical_time[15:4];
    wire signed [16:0] arg1 = $signed(logical_x) + $signed({5'd0, t_fast});
    wire signed [16:0] arg2 = ($signed(logical_x) >>> 1) - $signed({5'd0, t_slow});
    wire signed [12:0] tri1_comb = triangle_centered(arg1[11:0]);
    wire signed [12:0] tri2_comb = triangle_centered(arg2[11:0]);

    reg               valid_s1;
    reg signed [15:0] y_s1;
    reg signed [12:0] tri1_s1, tri2_s1;

    always @(posedge clk) begin
        valid_s1 <= logical_valid;
        y_s1     <= logical_y;
        tri1_s1  <= tri1_comb;
        tri2_s1  <= tri2_comb;
    end

    // S2: combine waves and register three logical band centers.
    wire signed [13:0] wave_offset = ($signed(tri1_s1) >>> 2) +
                                     ($signed(tri2_s1) >>> 3);
    wire signed [15:0] center0_comb = -16'sd2048 + wave_offset;
    wire signed [15:0] center1_comb =  16'sd0    - (wave_offset >>> 1);
    wire signed [15:0] center2_comb =  16'sd2048 + wave_offset;

    reg               valid_s2;
    reg signed [15:0] y_s2;
    reg signed [15:0] c0_s2, c1_s2, c2_s2;

    always @(posedge clk) begin
        valid_s2 <= valid_s1;
        y_s2     <= y_s1;
        c0_s2    <= center0_comb;
        c1_s2    <= center1_comb;
        c2_s2    <= center2_comb;
    end

    function [15:0] abs_diff;
        input signed [16:0] value;
        begin
            abs_diff = value[16] ? (~value + 17'd1) : value;
        end
    endfunction

    // S3: band membership, width ~= 0.16 logical unit.
    wire signed [16:0] d0 = $signed(y_s2) - $signed(c0_s2);
    wire signed [16:0] d1 = $signed(y_s2) - $signed(c1_s2);
    wire signed [16:0] d2 = $signed(y_s2) - $signed(c2_s2);

    reg valid_s3;
    reg m0_s3, m1_s3, m2_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        m0_s3    <= (abs_diff(d0) < 16'd640);
        m1_s3    <= (abs_diff(d1) < 16'd640);
        m2_s3    <= (abs_diff(d2) < 16'd640);
    end

    // S4: palette.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (m0_s3)
            rgb888 <= 24'h00D9C7;
        else if (m1_s3)
            rgb888 <= 24'h9B4DFF;
        else if (m2_s3)
            rgb888 <= 24'hFFAE2B;
        else
            rgb888 <= 24'h071629;
    end

endmodule
