`timescale 1ns / 1ps

// ASC v0.43 physical-space pattern bank.
// The artwork is fixed to 1280x720 and a 16x9 grid of 80x80-pixel cells.
// P1..P4 are fill variants; P5..P8 are hollow counterparts.
// Each pattern retains an exact four-clock external latency.
module pattern_gen (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        frame_tick,
    input  wire        pattern_valid,
    input  wire [3:0]  cell_x80,
    input  wire [6:0]  local_x80,
    input  wire [3:0]  cell_y80,
    input  wire [6:0]  local_y80,
    input  wire [4:0]  row_y40,
    input  wire [5:0]  local_y40,

    output wire [23:0] pattern1_rgb888,
    output wire [23:0] pattern2_rgb888,
    output wire [23:0] pattern3_rgb888,
    output wire [23:0] pattern4_rgb888,
    output wire [23:0] pattern5_rgb888,
    output wire [23:0] pattern6_rgb888,
    output wire [23:0] pattern7_rgb888,
    output wire [23:0] pattern8_rgb888
);

    // Exact physical scroll speeds at 60 Hz.
    // 20 / 40 / 80 px/s = 0.25 / 0.5 / 1.0 cell/s for 80px cells.
    wire [14:0] scroll20_cell80, scroll40_cell80, scroll80_cell80;
    wire [6:0]  scroll20_local80, scroll40_local80, scroll80_local80;
    wire [14:0] scroll20_row40;
    wire [6:0]  scroll20_local40;

    scroll_phase #(.CELL_SIZE(80), .SPEED_PPS(20)) u_scroll20_80 (
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
        .cell_offset(scroll20_cell80), .local_offset(scroll20_local80)
    );
    scroll_phase #(.CELL_SIZE(80), .SPEED_PPS(40)) u_scroll40_80 (
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
        .cell_offset(scroll40_cell80), .local_offset(scroll40_local80)
    );
    scroll_phase #(.CELL_SIZE(80), .SPEED_PPS(80)) u_scroll80_80 (
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
        .cell_offset(scroll80_cell80), .local_offset(scroll80_local80)
    );
    scroll_phase #(.CELL_SIZE(40), .SPEED_PPS(20)) u_scroll20_40 (
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
        .cell_offset(scroll20_row40), .local_offset(scroll20_local40)
    );

    pattern_square_fill u_p1 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .cell_y80(cell_y80), .local_y80(local_y80),
        .scroll_cell80(scroll40_cell80), .scroll_local80(scroll40_local80),
        .rgb888(pattern1_rgb888)
    );

    pattern_brick_fill u_p2 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .row_y40(row_y40), .local_y40(local_y40),
        .scroll_cell80(scroll20_cell80), .scroll_local80(scroll20_local80),
        .scroll_row40(scroll20_row40), .scroll_local40(scroll20_local40),
        .rgb888(pattern2_rgb888)
    );

    pattern_diagonal_fill u_p3 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .cell_y80(cell_y80), .local_y80(local_y80),
        .scroll_cell80_fast(scroll80_cell80), .scroll_local80_fast(scroll80_local80),
        .rgb888(pattern3_rgb888)
    );

    pattern_corner_fill u_p4 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .cell_y80(cell_y80), .local_y80(local_y80),
        .scroll_cell80(scroll80_cell80), .scroll_local80(scroll80_local80),
        .rgb888(pattern4_rgb888)
    );

    pattern_square_hollow u_p5 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .cell_y80(cell_y80), .local_y80(local_y80),
        .scroll_cell80(scroll20_cell80), .scroll_local80(scroll20_local80),
        .rgb888(pattern5_rgb888)
    );

    pattern_brick_hollow u_p6 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .row_y40(row_y40), .local_y40(local_y40),
        .scroll_cell80(scroll40_cell80), .scroll_local80(scroll40_local80),
        .rgb888(pattern6_rgb888)
    );

    pattern_diagonal_hollow u_p7 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .cell_y80(cell_y80), .local_y80(local_y80),
        .scroll_cell80_medium(scroll40_cell80), .scroll_local80_medium(scroll40_local80),
        .rgb888(pattern7_rgb888)
    );

    pattern_corner_hollow u_p8 (
        .clk(clk), .pattern_valid(pattern_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .cell_y80(cell_y80), .local_y80(local_y80),
        .scroll_cell80(scroll40_cell80), .scroll_local80(scroll40_local80),
        .rgb888(pattern8_rgb888)
    );

endmodule
