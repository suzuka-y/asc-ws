`timescale 1ns / 1ps

// Pattern 2: three contracting Manhattan-distance diamond outlines.
// Coordinates are signed Q3.12; all radii/widths use the same logical scale.
module pattern_manhattan_ripple (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    localparam [12:0] BASE0 = 13'd1434; // about 0.35
    localparam [12:0] BASE1 = 13'd4096; // 1.00
    localparam [12:0] BASE2 = 13'd6758; // about 1.65
    localparam signed [13:0] CENTER_GAP = 14'sd320;

    function [15:0] abs_q;
        input signed [15:0] value;
        begin
            abs_q = value[15] ? (~value + 16'd1) : value;
        end
    endfunction

    // S1: abs coordinate components + modulo-2.0 time motion.
    wire [15:0] ax_comb = abs_q(logical_x);
    wire [15:0] ay_comb = abs_q(logical_y);
    // modulo 8 seconds, speed 0.25 logical unit/second -> 0..2.0.
    wire [12:0] motion_comb = logical_time[14:2];

    reg        valid_s1;
    reg [15:0] ax_s1, ay_s1;
    reg [12:0] motion_s1;

    always @(posedge clk) begin
        valid_s1  <= logical_valid;
        ax_s1     <= ax_comb;
        ay_s1     <= ay_comb;
        motion_s1 <= motion_comb;
    end

    // S2: Manhattan distance + three wrap-safe radii.
    wire [16:0] d_comb = {1'b0, ax_s1} + {1'b0, ay_s1};
    wire [12:0] phase0_comb = BASE0 - motion_s1; // 13-bit natural modulo 8192
    wire [12:0] phase1_comb = BASE1 - motion_s1;
    wire [12:0] phase2_comb = BASE2 - motion_s1;

    wire signed [13:0] radius0_comb = $signed({1'b0, phase0_comb}) - CENTER_GAP;
    wire signed [13:0] radius1_comb = $signed({1'b0, phase1_comb}) - CENTER_GAP;
    wire signed [13:0] radius2_comb = $signed({1'b0, phase2_comb}) - CENTER_GAP;

    reg               valid_s2;
    reg [16:0]        d_s2;
    reg signed [13:0] radius0_s2, radius1_s2, radius2_s2;

    always @(posedge clk) begin
        valid_s2   <= valid_s1;
        d_s2       <= d_comb;
        radius0_s2 <= radius0_comb;
        radius1_s2 <= radius1_comb;
        radius2_s2 <= radius2_comb;
    end

    // S3: outline comparisons. Width ~= 0.0625 logical unit.
    wire signed [17:0] diff0 = $signed({1'b0, d_s2}) - $signed({{4{radius0_s2[13]}}, radius0_s2});
    wire signed [17:0] diff1 = $signed({1'b0, d_s2}) - $signed({{4{radius1_s2[13]}}, radius1_s2});
    wire signed [17:0] diff2 = $signed({1'b0, d_s2}) - $signed({{4{radius2_s2[13]}}, radius2_s2});

    wire [17:0] ad0 = diff0[17] ? (~diff0 + 18'd1) : diff0;
    wire [17:0] ad1 = diff1[17] ? (~diff1 + 18'd1) : diff1;
    wire [17:0] ad2 = diff2[17] ? (~diff2 + 18'd1) : diff2;

    reg       valid_s3;
    reg       m0_s3, m1_s3, m2_s3;
    reg [1:0] bg_index_s3;

    always @(posedge clk) begin
        valid_s3    <= valid_s2;
        m0_s3       <= !radius0_s2[13] && (ad0 < 18'd256);
        m1_s3       <= !radius1_s2[13] && (ad1 < 18'd256);
        m2_s3       <= !radius2_s2[13] && (ad2 < 18'd256);
        bg_index_s3 <= d_s2[11:10];
    end

    function [23:0] bg_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: bg_color = 24'h041C24;
                2'd1: bg_color = 24'h091638;
                2'd2: bg_color = 24'h210D32;
                default: bg_color = 24'h32101E;
            endcase
        end
    endfunction

    // S4: palette.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (m0_s3)
            rgb888 <= 24'h00D9C7;
        else if (m1_s3)
            rgb888 <= 24'hFF3D88;
        else if (m2_s3)
            rgb888 <= 24'hFFAE2B;
        else
            rgb888 <= bg_color(bg_index_s3);
    end

endmodule
