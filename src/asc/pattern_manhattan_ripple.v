`timescale 1ns / 1ps

// Pattern 2: three thick Manhattan-distance diamond outlines.
// ASC v0.4 timing contract: exactly 4 pixel-clock latency.
module pattern_manhattan_ripple (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    localparam [9:0] BASE0 = 10'd100;
    localparam [9:0] BASE1 = 10'd335;
    localparam [9:0] BASE2 = 10'd570;

    // P2-S1: absolute coordinate distance components and temporal motion.
    wire [9:0] dx_comb = (logical_x >= 10'd400) ?
                          (logical_x - 10'd400) : (10'd400 - logical_x);
    wire [9:0] dy_comb = (logical_y >= 10'd240) ?
                          (logical_y - 10'd240) : (10'd240 - logical_y);
    wire [9:0] motion_comb = {1'b0, frame_phase} +
                              {3'b000, frame_phase[8:2]} +
                              {4'b0000, frame_phase[8:3]};

    reg       valid_s1;
    reg [9:0] dx_s1;
    reg [9:0] dy_s1;
    reg [9:0] motion_s1;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s1  <= 1'b0;
            dx_s1     <= 10'd0;
            dy_s1     <= 10'd0;
            motion_s1 <= 10'd0;
        end else begin
            valid_s1  <= logical_valid;
            dx_s1     <= dx_comb;
            dy_s1     <= dy_comb;
            motion_s1 <= motion_comb;
        end
    end

    // P2-S2: Manhattan distance and virtual radii.
    wire [9:0] d_comb = dx_s1 + dy_s1;
    wire [10:0] phase0_ext = (BASE0 >= motion_s1) ?
        ({1'b0, BASE0} - {1'b0, motion_s1}) :
        (({1'b0, BASE0} + 11'd704) - {1'b0, motion_s1});
    wire [10:0] phase1_ext = (BASE1 >= motion_s1) ?
        ({1'b0, BASE1} - {1'b0, motion_s1}) :
        (({1'b0, BASE1} + 11'd704) - {1'b0, motion_s1});
    wire [10:0] phase2_ext = (BASE2 >= motion_s1) ?
        ({1'b0, BASE2} - {1'b0, motion_s1}) :
        (({1'b0, BASE2} + 11'd704) - {1'b0, motion_s1});

    wire signed [11:0] radius0_comb =
        $signed({1'b0, phase0_ext[9:0]}) - 12'sd32;
    wire signed [11:0] radius1_comb =
        $signed({1'b0, phase1_ext[9:0]}) - 12'sd32;
    wire signed [11:0] radius2_comb =
        $signed({1'b0, phase2_ext[9:0]}) - 12'sd32;

    reg               valid_s2;
    reg [9:0]         d_s2;
    reg signed [11:0] radius0_s2;
    reg signed [11:0] radius1_s2;
    reg signed [11:0] radius2_s2;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s2  <= 1'b0;
            d_s2      <= 10'd0;
            radius0_s2 <= 12'sd0;
            radius1_s2 <= 12'sd0;
            radius2_s2 <= 12'sd0;
        end else begin
            valid_s2   <= valid_s1;
            d_s2       <= d_comb;
            radius0_s2 <= radius0_comb;
            radius1_s2 <= radius1_comb;
            radius2_s2 <= radius2_comb;
        end
    end

    // P2-S3: outline distance comparisons.
    wire signed [12:0] diff0 =
        $signed({3'b000, d_s2}) - $signed({{1{radius0_s2[11]}}, radius0_s2});
    wire signed [12:0] diff1 =
        $signed({3'b000, d_s2}) - $signed({{1{radius1_s2[11]}}, radius1_s2});
    wire signed [12:0] diff2 =
        $signed({3'b000, d_s2}) - $signed({{1{radius2_s2[11]}}, radius2_s2});

    wire [12:0] abs_diff0 = diff0[12] ? (~diff0 + 13'd1) : diff0;
    wire [12:0] abs_diff1 = diff1[12] ? (~diff1 + 13'd1) : diff1;
    wire [12:0] abs_diff2 = diff2[12] ? (~diff2 + 13'd1) : diff2;

    reg       valid_s3;
    reg       m0_s3;
    reg       m1_s3;
    reg       m2_s3;
    reg [1:0] bg_index_s3;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s3    <= 1'b0;
            m0_s3       <= 1'b0;
            m1_s3       <= 1'b0;
            m2_s3       <= 1'b0;
            bg_index_s3 <= 2'd0;
        end else begin
            valid_s3    <= valid_s2;
            m0_s3       <= (abs_diff0 < 13'd24);
            m1_s3       <= (abs_diff1 < 13'd24);
            m2_s3       <= (abs_diff2 < 13'd24);
            bg_index_s3 <= d_s2[8:7];
        end
    end

    function [23:0] bg2_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: bg2_color = 24'h041C24;
                2'd1: bg2_color = 24'h091638;
                2'd2: bg2_color = 24'h210D32;
                default: bg2_color = 24'h32101E;
            endcase
        end
    endfunction

    // P2-S4: palette selection / output register.
    always @(posedge clk) begin
        if (!reset_n || !valid_s3)
            rgb888 <= 24'h000000;
        else if (m0_s3)
            rgb888 <= 24'h00D9C7;
        else if (m1_s3)
            rgb888 <= 24'hFF3D88;
        else if (m2_s3)
            rgb888 <= 24'hFFAE2B;
        else
            rgb888 <= bg2_color(bg_index_s3);
    end

endmodule
