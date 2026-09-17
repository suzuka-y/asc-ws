`timescale 1ns / 1ps

// Platform-independent ASC v0.42 core.
//
// Physical profile: 1280x720p60 RGB888 at 74.25 MHz.
// Pattern space/time: signed Q3.12 logical X/Y + UQ12.12 logical time.
// Pattern RTL is independent of physical resolution and physical refresh.
//
// Fixed pipeline contract:
//   Display Space : 1 clock
//   Pattern Bank  : 4 clocks
//   Pattern Mixer : 4 clocks
//   Fade          : 1 clock
//   --------------------------------
//   Total         : 10 pixel clocks
module asc_core (
    input  wire        clk,
    input  wire        rst_n_raw,

    output wire        pclk,
    output wire        hsync,
    output wire        vsync,
    output wire        de,
    output wire [23:0] rgb
);

    // ------------------------------------------------------------------
    // Reset boundary. rst_n_raw is not distributed beyond this instance.
    // ------------------------------------------------------------------
    wire core_rst_n;

    reset_synchronizer u_reset_synchronizer (
        .clk        (clk),
        .rst_n_raw  (rst_n_raw),
        .core_rst_n (core_rst_n)
    );

    // ------------------------------------------------------------------
    // Physical display space / deterministic control state.
    // ------------------------------------------------------------------
    wire [10:0] h_count;
    wire [9:0]  v_count;
    wire [10:0] physical_x;
    wire [9:0]  physical_y;
    wire        physical_valid;
    wire        timing_hsync;
    wire        timing_vsync;
    wire        timing_de;
    wire        frame_tick;

    timing_generator u_timing_generator (
        .clk            (clk),
        .reset_n        (core_rst_n),
        .h_count        (h_count),
        .v_count        (v_count),
        .physical_x     (physical_x),
        .physical_y     (physical_y),
        .physical_valid (physical_valid),
        .hsync          (timing_hsync),
        .vsync          (timing_vsync),
        .de             (timing_de),
        .frame_tick     (frame_tick)
    );

    wire [23:0] logical_time;

    logical_time_controller u_logical_time_controller (
        .clk          (clk),
        .reset_n      (core_rst_n),
        .frame_tick   (frame_tick),
        .logical_time (logical_time)
    );

    wire [9:0] scene_frame_count;
    wire [7:0] pattern_mask;
    wire [1:0] mix_shift;

    scene_controller u_scene_controller (
        .clk               (clk),
        .reset_n           (core_rst_n),
        .frame_tick        (frame_tick),
        .scene_frame_count (scene_frame_count),
        .pattern_mask      (pattern_mask),
        .mix_shift         (mix_shift)
    );

    // ------------------------------------------------------------------
    // DS: physical pixel -> normalized logical coordinate (1 clock).
    // ------------------------------------------------------------------
    wire signed [15:0] logical_x;
    wire signed [15:0] logical_y;
    wire               logical_valid;

    display_space u_display_space (
        .clk            (clk),
        .physical_x     (physical_x),
        .physical_y     (physical_y),
        .physical_valid (physical_valid),
        .logical_x      (logical_x),
        .logical_y      (logical_y),
        .logical_valid  (logical_valid)
    );

    // State aligned to the Display Space output sample epoch.
    // These are reset-free datapath-alignment registers.
    reg [23:0] logical_time_ds;
    reg [7:0]  pattern_mask_ds;
    reg [1:0]  mix_shift_ds;

    always @(posedge clk) begin
        logical_time_ds <= logical_time;
        pattern_mask_ds <= pattern_mask;
        mix_shift_ds    <= mix_shift;
    end

    // ------------------------------------------------------------------
    // Fade-level decode is performed at the raw pixel epoch. The decoded
    // value is delayed nine clocks to meet the corresponding mixer pixel.
    // ------------------------------------------------------------------
    wire [3:0] fade_level_raw;

    fade_level_decoder u_fade_level_decoder (
        .scene_frame_count (scene_frame_count),
        .fade_level        (fade_level_raw)
    );

    reg [35:0] fade_level_pipe9;
    always @(posedge clk) begin
        fade_level_pipe9 <= {fade_level_pipe9[31:0], fade_level_raw};
    end

    wire [3:0] fade_level_fade = fade_level_pipe9[35:32];

    // ------------------------------------------------------------------
    // P1..P8: four-clock normalized-coordinate/time pattern bank.
    // ------------------------------------------------------------------
    wire [23:0] pattern1_rgb888;
    wire [23:0] pattern2_rgb888;
    wire [23:0] pattern3_rgb888;
    wire [23:0] pattern4_rgb888;
    wire [23:0] pattern5_rgb888;
    wire [23:0] pattern6_rgb888;
    wire [23:0] pattern7_rgb888;
    wire [23:0] pattern8_rgb888;

    pattern_gen u_pattern_gen (
        .clk             (clk),
        .logical_valid   (logical_valid),
        .logical_x       (logical_x),
        .logical_y       (logical_y),
        .logical_time    (logical_time_ds),
        .pattern1_rgb888 (pattern1_rgb888),
        .pattern2_rgb888 (pattern2_rgb888),
        .pattern3_rgb888 (pattern3_rgb888),
        .pattern4_rgb888 (pattern4_rgb888),
        .pattern5_rgb888 (pattern5_rgb888),
        .pattern6_rgb888 (pattern6_rgb888),
        .pattern7_rgb888 (pattern7_rgb888),
        .pattern8_rgb888 (pattern8_rgb888)
    );

    // mask/mix_shift meet the pattern RGBs at the mixer input.
    reg [31:0] pattern_mask_pipe4;
    reg [7:0]  mix_shift_pipe4;

    always @(posedge clk) begin
        pattern_mask_pipe4 <= {pattern_mask_pipe4[23:0], pattern_mask_ds};
        mix_shift_pipe4    <= {mix_shift_pipe4[5:0], mix_shift_ds};
    end

    wire [7:0] mixer_pattern_mask = pattern_mask_pipe4[31:24];
    wire [1:0] mixer_mix_shift    = mix_shift_pipe4[7:6];

    // ------------------------------------------------------------------
    // M1..M4: balanced mixer. M3 normalization and M4 Gray subtraction
    // remain separated by a mandatory register boundary.
    // ------------------------------------------------------------------
    wire [23:0] mixed_rgb888;

    pattern_mixer u_pattern_mixer (
        .clk             (clk),
        .pattern_mask    (mixer_pattern_mask),
        .mix_shift       (mixer_mix_shift),
        .pattern1_rgb888 (pattern1_rgb888),
        .pattern2_rgb888 (pattern2_rgb888),
        .pattern3_rgb888 (pattern3_rgb888),
        .pattern4_rgb888 (pattern4_rgb888),
        .pattern5_rgb888 (pattern5_rgb888),
        .pattern6_rgb888 (pattern6_rgb888),
        .pattern7_rgb888 (pattern7_rgb888),
        .pattern8_rgb888 (pattern8_rgb888),
        .mixed_rgb888    (mixed_rgb888)
    );

    // ------------------------------------------------------------------
    // F1: one-clock shift/add fade scaler.
    // ------------------------------------------------------------------
    wire [23:0] faded_rgb888;

    fade_scaler u_fade_scaler (
        .clk          (clk),
        .fade_level   (fade_level_fade),
        .mixed_rgb888 (mixed_rgb888),
        .faded_rgb888 (faded_rgb888)
    );

    // ------------------------------------------------------------------
    // Raw sync/DE aligned to the exact total 10-clock RGB latency.
    // ------------------------------------------------------------------
    reg [9:0] hsync_pipe10;
    reg [9:0] vsync_pipe10;
    reg [9:0] de_pipe10;

    always @(posedge clk) begin
        hsync_pipe10 <= {hsync_pipe10[8:0], timing_hsync};
        vsync_pipe10 <= {vsync_pipe10[8:0], timing_vsync};
        de_pipe10    <= {de_pipe10[8:0], timing_de};
    end

    // Pipeline fill is deterministic control state and is reset.
    reg [9:0] output_valid_pipe;

    always @(posedge clk or negedge core_rst_n) begin
        if (!core_rst_n)
            output_valid_pipe <= 10'd0;
        else
            output_valid_pipe <= {output_valid_pipe[8:0], 1'b1};
    end

    wire output_valid = output_valid_pipe[9];

    dpi_output u_dpi_output (
        .clk            (clk),
        .output_valid   (output_valid),
        .timing_hsync   (hsync_pipe10[9]),
        .timing_vsync   (vsync_pipe10[9]),
        .timing_de      (de_pipe10[9]),
        .pattern_rgb888 (faded_rgb888),
        .pclk           (pclk),
        .hsync          (hsync),
        .vsync          (vsync),
        .de             (de),
        .rgb            (rgb)
    );

endmodule
