`timescale 1ns / 1ps

// Pattern 7: eight-direction angular pinwheel without atan/division.
module pattern_angular_pinwheel (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    function [15:0] abs_q;
        input signed [15:0] value;
        begin
            abs_q = value[15] ? (~value + 16'd1) : value;
        end
    endfunction

    // S1: sign and absolute magnitude.
    wire [15:0] ax_comb = abs_q(logical_x);
    wire [15:0] ay_comb = abs_q(logical_y);

    reg       valid_s1;
    reg       x_pos_s1, y_pos_s1;
    reg [15:0] ax_s1, ay_s1;
    reg [2:0] time_sector_s1;

    always @(posedge clk) begin
        valid_s1       <= logical_valid;
        x_pos_s1       <= ~logical_x[15];
        y_pos_s1       <= ~logical_y[15];
        ax_s1          <= ax_comb;
        ay_s1          <= ay_comb;
        time_sector_s1 <= logical_time[14:12];
    end

    // S2: 8-sector classification using only compare/shift.
    reg [2:0] sector_comb;
    always @* begin
        if ({1'b0, ax_s1} > ({1'b0, ay_s1} << 1))
            sector_comb = x_pos_s1 ? 3'd0 : 3'd4;
        else if ({1'b0, ay_s1} > ({1'b0, ax_s1} << 1))
            sector_comb = y_pos_s1 ? 3'd2 : 3'd6;
        else if (x_pos_s1 && y_pos_s1)
            sector_comb = 3'd1;
        else if (!x_pos_s1 && y_pos_s1)
            sector_comb = 3'd3;
        else if (!x_pos_s1 && !y_pos_s1)
            sector_comb = 3'd5;
        else
            sector_comb = 3'd7;
    end

    reg       valid_s2;
    reg [2:0] sector_s2;
    reg [2:0] time_sector_s2;

    always @(posedge clk) begin
        valid_s2       <= valid_s1;
        sector_s2      <= sector_comb;
        time_sector_s2 <= time_sector_s1;
    end

    // S3: animated palette index.
    reg       valid_s3;
    reg [2:0] color_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        color_s3 <= sector_s2 + time_sector_s2;
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

    // S4: palette.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else
            rgb888 <= vivid8(color_s3);
    end

endmodule
