`timescale 1ns / 1ps

// ASC v0.42 pattern bank.
// All patterns consume only normalized logical coordinates/time and have an
// exact four-clock external latency with one-sample-per-clock throughput.
module pattern_gen (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,

    output wire [23:0] pattern1_rgb888,
    output wire [23:0] pattern2_rgb888,
    output wire [23:0] pattern3_rgb888,
    output wire [23:0] pattern4_rgb888,
    output wire [23:0] pattern5_rgb888,
    output wire [23:0] pattern6_rgb888,
    output wire [23:0] pattern7_rgb888,
    output wire [23:0] pattern8_rgb888
);

    pattern_isometric_cubes u_p1 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern1_rgb888)
    );

    pattern_manhattan_ripple u_p2 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern2_rgb888)
    );

    pattern_diagonal_moire u_p3 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern3_rgb888)
    );

    pattern_broad_wave_bands u_p4 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern4_rgb888)
    );

    pattern_truchet_lines u_p5 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern5_rgb888)
    );

    pattern_hash_mosaic u_p6 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern6_rgb888)
    );

    pattern_angular_pinwheel u_p7 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern7_rgb888)
    );

    pattern_pulse_columns u_p8 (
        .clk(clk), .logical_valid(logical_valid),
        .logical_x(logical_x), .logical_y(logical_y),
        .logical_time(logical_time), .rgb888(pattern8_rgb888)
    );

endmodule
