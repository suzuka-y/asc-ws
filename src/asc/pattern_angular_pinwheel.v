`timescale 1ns / 1ps

// Pattern 7: angular eight-sector pinwheel.
// ASC v0.4 timing contract: exactly 4 pixel-clock latency.
module pattern_angular_pinwheel (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    // P7-S1: center-relative absolute coordinates and signs.
    wire x_positive_comb = (logical_x >= 10'd400);
    wire y_positive_comb = (logical_y >= 10'd240);
    wire [9:0] ax_comb = x_positive_comb ?
                         (logical_x - 10'd400) : (10'd400 - logical_x);
    wire [9:0] ay_comb = y_positive_comb ?
                         (logical_y - 10'd240) : (10'd240 - logical_y);

    reg       valid_s1;
    reg       x_positive_s1;
    reg       y_positive_s1;
    reg [9:0] ax_s1;
    reg [9:0] ay_s1;
    reg [2:0] phase_sector_s1;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s1 <= 1'b0;
            x_positive_s1 <= 1'b0;
            y_positive_s1 <= 1'b0;
            ax_s1 <= 10'd0;
            ay_s1 <= 10'd0;
            phase_sector_s1 <= 3'd0;
        end else begin
            valid_s1 <= logical_valid;
            x_positive_s1 <= x_positive_comb;
            y_positive_s1 <= y_positive_comb;
            ax_s1 <= ax_comb;
            ay_s1 <= ay_comb;
            phase_sector_s1 <= frame_phase[7:5];
        end
    end

    // P7-S2: geometric sector classification.
    reg [2:0] sector_comb;
    always @* begin
        if (ax_s1 > (ay_s1 << 1))
            sector_comb = x_positive_s1 ? 3'd0 : 3'd4;
        else if (ay_s1 > (ax_s1 << 1))
            sector_comb = y_positive_s1 ? 3'd2 : 3'd6;
        else if (x_positive_s1 && y_positive_s1)
            sector_comb = 3'd1;
        else if (!x_positive_s1 && y_positive_s1)
            sector_comb = 3'd3;
        else if (!x_positive_s1 && !y_positive_s1)
            sector_comb = 3'd5;
        else
            sector_comb = 3'd7;
    end

    reg       valid_s2;
    reg [2:0] sector_s2;
    reg [2:0] phase_sector_s2;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s2 <= 1'b0;
            sector_s2 <= 3'd0;
            phase_sector_s2 <= 3'd0;
        end else begin
            valid_s2 <= valid_s1;
            sector_s2 <= sector_comb;
            phase_sector_s2 <= phase_sector_s1;
        end
    end

    // P7-S3: animated palette index.
    reg       valid_s3;
    reg [2:0] q7_s3;

    always @(posedge clk) begin
        if (!reset_n) begin
            valid_s3 <= 1'b0;
            q7_s3 <= 3'd0;
        end else begin
            valid_s3 <= valid_s2;
            q7_s3 <= sector_s2 + phase_sector_s2;
        end
    end

    function [23:0] p7_color;
        input [2:0] index;
        begin
            case (index)
                3'd0: p7_color = 24'h00D9C7;
                3'd1: p7_color = 24'h2F6BFF;
                3'd2: p7_color = 24'h9B4DFF;
                3'd3: p7_color = 24'hFF3D88;
                3'd4: p7_color = 24'hFFAE2B;
                3'd5: p7_color = 24'h42D65A;
                3'd6: p7_color = 24'h00BDEB;
                default: p7_color = 24'hE45CFF;
            endcase
        end
    endfunction

    // P7-S4: palette lookup / output register.
    always @(posedge clk) begin
        if (!reset_n || !valid_s3)
            rgb888 <= 24'h000000;
        else
            rgb888 <= p7_color(q7_s3);
    end

endmodule
