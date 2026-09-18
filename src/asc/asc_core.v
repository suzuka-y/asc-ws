`timescale 1ns / 1ps

// Platform-independent ASC v0.43 core for the tapeout artwork.
//
// Physical profile: 1280x720p60 RGB888 at 74.25 MHz.
// v0.43 intentionally does NOT separate physical and logical display spaces.
// Patterns consume a fixed 16x9 physical grid (80x80 px/cell).
// Runtime-normalized display-space research is deferred to FPGA work.
//
// Fixed pipeline contract for the current v0.43 integration:
//   Pattern input alignment : 1 clock
//   Pattern Bank            : 4 clocks
//   Pattern Mixer           : 7 clocks
//   Fade                    : 1 clock
//   DPI output register     : 1 clock
//   -----------------------------------
//   Total                   : 14 pixel clocks
//
// The internal timing/fade alignment below is 13 clocks; dpi_output
// registers RGB/sync/DE once more at the external pad-facing boundary.
module asc_core (
    input  wire        clk,
    input  wire        rst_n_raw,

    output wire        pclk,
    output wire        hsync,
    output wire        vsync,
    output wire        de,
    output wire [23:0] rgb
);

    wire core_rst_n;
    reset_synchronizer u_reset_synchronizer (
        .clk(clk), .rst_n_raw(rst_n_raw), .core_rst_n(core_rst_n)
    );

    wire [10:0] h_count;
    wire [9:0]  v_count;
    wire [10:0] physical_x;
    wire [9:0]  physical_y;
    wire        physical_valid;
    wire [3:0]  cell_x80;
    wire [6:0]  local_x80;
    wire [3:0]  cell_y80;
    wire [6:0]  local_y80;
    wire [4:0]  row_y40;
    wire [5:0]  local_y40;
    wire timing_hsync, timing_vsync, timing_de, frame_tick;

    timing_generator u_timing_generator (
        .clk(clk), .reset_n(core_rst_n),
        .h_count(h_count), .v_count(v_count),
        .physical_x(physical_x), .physical_y(physical_y),
        .physical_valid(physical_valid),
        .cell_x80(cell_x80), .local_x80(local_x80),
        .cell_y80(cell_y80), .local_y80(local_y80),
        .row_y40(row_y40), .local_y40(local_y40),
        .hsync(timing_hsync), .vsync(timing_vsync), .de(timing_de),
        .frame_tick(frame_tick)
    );

    wire [9:0] scene_frame_count;
    wire [7:0] pattern_mask;
    wire [1:0] mix_shift;
    scene_controller u_scene_controller (
        .clk(clk), .reset_n(core_rst_n), .frame_tick(frame_tick),
        .scene_frame_count(scene_frame_count),
        .pattern_mask(pattern_mask), .mix_shift(mix_shift)
    );

    // --------------------------------------------------------------
    // One-clock pattern-input alignment stage.  This replaces the former
    // normalized Display Space stage without changing total RGB latency.
    // --------------------------------------------------------------
    reg        pattern_valid_s1;
    reg [3:0]  cell_x80_s1, cell_y80_s1;
    reg [6:0]  local_x80_s1, local_y80_s1;
    reg [4:0]  row_y40_s1;
    reg [5:0]  local_y40_s1;
    reg [7:0]  pattern_mask_s1;
    reg [1:0]  mix_shift_s1;

    always @(posedge clk) begin
        pattern_valid_s1 <= physical_valid;
        cell_x80_s1      <= cell_x80;
        local_x80_s1     <= local_x80;
        cell_y80_s1      <= cell_y80;
        local_y80_s1     <= local_y80;
        row_y40_s1       <= row_y40;
        local_y40_s1     <= local_y40;
        pattern_mask_s1  <= pattern_mask;
        mix_shift_s1     <= mix_shift;
    end

    // Fade decode at raw pixel epoch; delay twelve clocks to meet mixed RGB.
    wire [3:0] fade_level_raw;
    fade_level_decoder u_fade_level_decoder (
        .scene_frame_count(scene_frame_count), .fade_level(fade_level_raw)
    );

    reg [47:0] fade_level_pipe12;
    always @(posedge clk)
        fade_level_pipe12 <= {fade_level_pipe12[43:0], fade_level_raw};
    wire [3:0] fade_level_fade = fade_level_pipe12[47:44];

    wire [23:0] pattern1_rgb888, pattern2_rgb888, pattern3_rgb888, pattern4_rgb888;
    wire [23:0] pattern5_rgb888, pattern6_rgb888, pattern7_rgb888, pattern8_rgb888;

    pattern_gen u_pattern_gen (
        .clk(clk), .reset_n(core_rst_n), .frame_tick(frame_tick),
        .pattern_valid(pattern_valid_s1),
        .cell_x80(cell_x80_s1), .local_x80(local_x80_s1),
        .cell_y80(cell_y80_s1), .local_y80(local_y80_s1),
        .row_y40(row_y40_s1), .local_y40(local_y40_s1),
        .pattern1_rgb888(pattern1_rgb888), .pattern2_rgb888(pattern2_rgb888),
        .pattern3_rgb888(pattern3_rgb888), .pattern4_rgb888(pattern4_rgb888),
        .pattern5_rgb888(pattern5_rgb888), .pattern6_rgb888(pattern6_rgb888),
        .pattern7_rgb888(pattern7_rgb888), .pattern8_rgb888(pattern8_rgb888)
    );

    reg [31:0] pattern_mask_pipe4;
    reg [7:0]  mix_shift_pipe4;
    always @(posedge clk) begin
        pattern_mask_pipe4 <= {pattern_mask_pipe4[23:0], pattern_mask_s1};
        mix_shift_pipe4    <= {mix_shift_pipe4[5:0], mix_shift_s1};
    end
    wire [7:0] mixer_pattern_mask = pattern_mask_pipe4[31:24];
    wire [1:0] mixer_mix_shift    = mix_shift_pipe4[7:6];

    wire [23:0] mixed_rgb888;
    pattern_mixer u_pattern_mixer (
        .clk(clk), .pattern_mask(mixer_pattern_mask), .mix_shift(mixer_mix_shift),
        .pattern1_rgb888(pattern1_rgb888), .pattern2_rgb888(pattern2_rgb888),
        .pattern3_rgb888(pattern3_rgb888), .pattern4_rgb888(pattern4_rgb888),
        .pattern5_rgb888(pattern5_rgb888), .pattern6_rgb888(pattern6_rgb888),
        .pattern7_rgb888(pattern7_rgb888), .pattern8_rgb888(pattern8_rgb888),
        .mixed_rgb888(mixed_rgb888)
    );

    wire [23:0] faded_rgb888;
    fade_scaler u_fade_scaler (
        .clk(clk), .fade_level(fade_level_fade),
        .mixed_rgb888(mixed_rgb888), .faded_rgb888(faded_rgb888)
    );

    reg [12:0] hsync_pipe13, vsync_pipe13, de_pipe13;
    always @(posedge clk) begin
        hsync_pipe13 <= {hsync_pipe13[11:0], timing_hsync};
        vsync_pipe13 <= {vsync_pipe13[11:0], timing_vsync};
        de_pipe13    <= {de_pipe13[11:0], timing_de};
    end

    reg [12:0] output_valid_pipe;
    always @(posedge clk or negedge core_rst_n) begin
        if (!core_rst_n)
            output_valid_pipe <= 13'd0;
        else
            output_valid_pipe <= {output_valid_pipe[11:0], 1'b1};
    end
    wire output_valid = output_valid_pipe[12];

    dpi_output u_dpi_output (
        .clk(clk), .output_valid(output_valid),
        .timing_hsync(hsync_pipe13[12]), .timing_vsync(vsync_pipe13[12]),
        .timing_de(de_pipe13[12]), .pattern_rgb888(faded_rgb888),
        .pclk(pclk), .hsync(hsync), .vsync(vsync), .de(de), .rgb(rgb)
    );

endmodule
