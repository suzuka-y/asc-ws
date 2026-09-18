`timescale 1ns / 1ps

// Deterministic cell-style generator for ASC v0.43.
// No LFSR, multiplier, divider, or general modulo is used.
// Signed cell indices may extend beyond the visible 16x9 grid during scroll.
module pattern_cell_style #(
    parameter [15:0] SALT = 16'h0001,
    parameter [3:0]  BG_THRESHOLD = 4'd4
) (
    input  wire signed [15:0] cell_x,
    input  wire signed [15:0] cell_y,
    output wire               is_background,
    output wire [2:0]         color_index,
    output wire [1:0]         orientation,
    output wire [1:0]         size_sel
);

    wire [15:0] x_bits = cell_x;
    wire [15:0] y_bits = cell_y;
    wire [15:0] y_rot9 = {y_bits[6:0], y_bits[15:7]};
    wire [15:0] y_rot4 = {y_bits[3:0], y_bits[15:4]};
    wire [15:0] x_sh3  = {x_bits[12:0], 3'b000};
    wire [15:0] add_mix = x_bits + y_rot9 + SALT;
    wire [15:0] h0 = add_mix ^ x_sh3 ^ (y_bits >> 2);
    wire [15:0] h1 = h0 ^ (h0 >> 5) ^ {h0[8:0], h0[15:9]};
    wire [15:0] h2 = h1 ^ (x_bits & y_rot4);
    wire [2:0] raw_color = h2[6:4];

    assign is_background = (h2[3:0] < BG_THRESHOLD);
    assign color_index = (raw_color == 3'd0) ? 3'd7 : raw_color;
    assign orientation = h2[8:7];
    assign size_sel     = h2[10:9];

endmodule
