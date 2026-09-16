`timescale 1ns / 1ps

// ASC v0.41 parallel pattern bank.
// Contract: all eight patterns accept one logical pixel every clock and return
// the corresponding RGB888 value exactly 4 clocks later.
module pattern_gen (
    input  wire        clk,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output wire [23:0] pattern1_rgb888,
    output wire [23:0] pattern2_rgb888,
    output wire [23:0] pattern3_rgb888,
    output wire [23:0] pattern4_rgb888,
    output wire [23:0] pattern5_rgb888,
    output wire [23:0] pattern6_rgb888,
    output wire [23:0] pattern7_rgb888,
    output wire [23:0] pattern8_rgb888
);

    pattern_isometric_cubes u_pattern_isometric_cubes (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern1_rgb888)
    );

    pattern_manhattan_ripple u_pattern_manhattan_ripple (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern2_rgb888)
    );

    pattern_diagonal_moire u_pattern_diagonal_moire (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern3_rgb888)
    );

    pattern_broad_wave_bands u_pattern_broad_wave_bands (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern4_rgb888)
    );

    pattern_truchet_lines u_pattern_truchet_lines (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern5_rgb888)
    );

    pattern_hash_mosaic u_pattern_hash_mosaic (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern6_rgb888)
    );

    pattern_angular_pinwheel u_pattern_angular_pinwheel (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern7_rgb888)
    );

    pattern_pulse_columns u_pattern_pulse_columns (
        .clk(clk),
        .logical_valid(logical_valid), .logical_x(logical_x),
        .logical_y(logical_y), .frame_phase(frame_phase),
        .rgb888(pattern8_rgb888)
    );

endmodule
