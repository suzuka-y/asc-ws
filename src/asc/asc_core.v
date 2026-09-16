`timescale 1ns / 1ps

// Platform-independent ASC v0.41 core.
//
// v0.41 keeps the v0.4 display function and 10-clock pixel latency while
// refining reset distribution and the two measured timing hot spots.
//
// Reset architecture:
//   rst_n_raw -> 2-FF async-assert/sync-deassert synchronizer -> core_rst_n
//   core_rst_n is used only by deterministic control/state and output-valid.
//   Arithmetic/data pipeline registers are intentionally reset-free.
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
    output wire [23:0] rgb,
    output wire [3:0]  debug
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
    // Real display space / deterministic control state.
    // ------------------------------------------------------------------
    wire [9:0] h_count;
    wire [9:0] v_count;
    wire [9:0] physical_x;
    wire [9:0] physical_y;
    wire       physical_valid;
    wire       timing_hsync;
    wire       timing_vsync;
    wire       timing_de;
    wire       frame_tick;

    wire [8:0] frame_phase;
    wire [9:0] scene_frame_count;
    wire [7:0] pattern_mask;
    wire [1:0] mix_shift;

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

    pattern_phase_controller u_pattern_phase_controller (
        .clk         (clk),
        .reset_n     (core_rst_n),
        .frame_tick  (frame_tick),
        .frame_phase (frame_phase)
    );

    scene_controller u_scene_controller (
        .clk               (clk),
        .reset_n           (core_rst_n),
        .frame_tick        (frame_tick),
        .scene_frame_count (scene_frame_count),
        .pattern_mask      (pattern_mask),
        .mix_shift         (mix_shift)
    );

    // ------------------------------------------------------------------
    // Reset-free datapath.
    // DS: real display space -> logical display space (1 clock).
    // ------------------------------------------------------------------
    wire [9:0] logical_x;
    wire [9:0] logical_y;
    wire       logical_valid;

    display_space u_display_space (
        .clk            (clk),
        .physical_x     (physical_x),
        .physical_y     (physical_y),
        .physical_valid (physical_valid),
        .logical_x      (logical_x),
        .logical_y      (logical_y),
        .logical_valid  (logical_valid)
    );

    // Sideband state crossing the same display-space boundary.
    // These are datapath-alignment registers and deliberately have no reset.
    reg [8:0] frame_phase_ds;
    reg [7:0] pattern_mask_ds;
    reg [1:0] mix_shift_ds;

    always @(posedge clk) begin
        frame_phase_ds  <= frame_phase;
        pattern_mask_ds <= pattern_mask;
        mix_shift_ds    <= mix_shift;
    end

    // ------------------------------------------------------------------
    // Fade-level decode is moved ahead of the pixel arithmetic path.
    // The decoded 4-bit value is delayed nine clocks so it reaches the
    // one-clock fade stage together with the corresponding mixer pixel.
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
    // P1..P4: pattern bank (4 clocks, one pixel/clock throughput).
    // Pattern datapath registers are reset-free in v0.41.
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
        .frame_phase     (frame_phase_ds),
        .pattern1_rgb888 (pattern1_rgb888),
        .pattern2_rgb888 (pattern2_rgb888),
        .pattern3_rgb888 (pattern3_rgb888),
        .pattern4_rgb888 (pattern4_rgb888),
        .pattern5_rgb888 (pattern5_rgb888),
        .pattern6_rgb888 (pattern6_rgb888),
        .pattern7_rgb888 (pattern7_rgb888),
        .pattern8_rgb888 (pattern8_rgb888)
    );

    // pattern_mask / mix_shift must arrive at mixer input with the pattern
    // RGB values, four clocks after the display-space boundary.
    reg [31:0] pattern_mask_pipe4;
    reg [7:0]  mix_shift_pipe4;

    always @(posedge clk) begin
        pattern_mask_pipe4 <= {pattern_mask_pipe4[23:0], pattern_mask_ds};
        mix_shift_pipe4    <= {mix_shift_pipe4[5:0], mix_shift_ds};
    end

    wire [7:0] mixer_pattern_mask = pattern_mask_pipe4[31:24];
    wire [1:0] mixer_mix_shift    = mix_shift_pipe4[7:6];

    // ------------------------------------------------------------------
    // M1..M4: mixer (4 clocks), reset-free datapath.
    // M3 registers normalized RGB; M4 performs Gray subtraction.
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
    // F1: fade scale (1 clock). Level decode has already been completed.
    // ------------------------------------------------------------------
    wire [23:0] faded_rgb888;

    fade_scaler u_fade_scaler (
        .clk          (clk),
        .fade_level   (fade_level_fade),
        .mixed_rgb888 (mixed_rgb888),
        .faded_rgb888 (faded_rgb888)
    );

    // ------------------------------------------------------------------
    // Sync/DE sideband pipeline: exact total pixel latency = 10 clocks.
    // Reset-free: output_valid masks its contents until pipeline fill.
    // ------------------------------------------------------------------
    reg [9:0] hsync_pipe10;
    reg [9:0] vsync_pipe10;
    reg [9:0] de_pipe10;

    always @(posedge clk) begin
        hsync_pipe10 <= {hsync_pipe10[8:0], timing_hsync};
        vsync_pipe10 <= {vsync_pipe10[8:0], timing_vsync};
        de_pipe10    <= {de_pipe10[8:0], timing_de};
    end

    // ------------------------------------------------------------------
    // Pipeline-valid generator. This is control state and is reset.
    // It becomes High on the same clock at which the first complete 10-clock
    // pixel result becomes available at the fade output.
    // ------------------------------------------------------------------
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

    // Debug remains tied to the undelayed real raster for bring-up/STA use.
    debug_signal_gen u_debug_signal_gen (
        .reset_n (core_rst_n),
        .h_count (h_count),
        .v_count (v_count),
        .de      (timing_de),
        .debug   (debug)
    );

endmodule
