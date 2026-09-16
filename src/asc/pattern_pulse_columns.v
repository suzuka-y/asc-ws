`timescale 1ns / 1ps

// Pattern 8: pulse columns on black background.
// ASC v0.41 timing contract: exactly 4 pixel-clock latency.
module pattern_pulse_columns (
    input  wire        clk,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    // P8-S1: column selection, phase and color index.
    wire [4:0] c_comb = logical_x[9:5];
    wire [4:0] u_comb = logical_x[4:0];
    wire mx_comb = (u_comb >= 5'd6) && (u_comb < 5'd26);
    wire [6:0] three_c_comb = {2'd0, c_comb} + ({2'd0, c_comb} << 1);
    wire [5:0] p8_comb = frame_phase[5:0] + three_c_comb[5:0];
    wire [2:0] q8_color_comb = c_comb[2:0] + frame_phase[7:5];

    reg       valid_s1;
    reg       mx_s1;
    reg [5:0] p8_s1;
    reg [9:0] y_s1;
    reg [2:0] q8_color_s1;

    always @(posedge clk) begin
        valid_s1 <= logical_valid;
        mx_s1 <= mx_comb;
        p8_s1 <= p8_comb;
        y_s1 <= logical_y;
        q8_color_s1 <= q8_color_comb;
    end

    // P8-S2: triangle height and y threshold.
    wire [6:0] t8_triangle = (p8_s1 <= 6'd32) ?
                              {1'b0, p8_s1} : (7'd64 - {1'b0, p8_s1});
    wire [3:0] q8_height = t8_triangle[5:2];
    wire [9:0] q8_ext = {6'd0, q8_height};
    wire [9:0] h8_comb = (q8_ext << 6) - (q8_ext << 2);
    wire [9:0] y_threshold_comb = 10'd480 - h8_comb;

    reg       valid_s2;
    reg       mx_s2;
    reg [9:0] y_s2;
    reg [9:0] y_threshold_s2;
    reg [2:0] q8_color_s2;

    always @(posedge clk) begin
        valid_s2 <= valid_s1;
        mx_s2 <= mx_s1;
        y_s2 <= y_s1;
        y_threshold_s2 <= y_threshold_comb;
        q8_color_s2 <= q8_color_s1;
    end

    // P8-S3: final geometry hit decision.
    reg       valid_s3;
    reg       m8_s3;
    reg [2:0] q8_color_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        m8_s3 <= mx_s2 && (y_s2 >= y_threshold_s2);
        q8_color_s3 <= q8_color_s2;
    end

    function [23:0] pulse_color;
        input [2:0] index;
        begin
            case (index)
                3'd0: pulse_color = 24'h00D9C7;
                3'd1: pulse_color = 24'h2F6BFF;
                3'd2: pulse_color = 24'h9B4DFF;
                3'd3: pulse_color = 24'hFF3D88;
                3'd4: pulse_color = 24'hFFAE2B;
                3'd5: pulse_color = 24'h42D65A;
                3'd6: pulse_color = 24'h00BDEB;
                default: pulse_color = 24'hE45CFF;
            endcase
        end
    endfunction

    // P8-S4: palette lookup / output register.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (m8_s3)
            rgb888 <= pulse_color(q8_color_s3);
        else
            rgb888 <= 24'h000000;
    end

endmodule
