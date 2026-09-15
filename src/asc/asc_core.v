`timescale 1ns / 1ps

// Platform-independent ASC v0.4 core.
//
// v0.4 architecture goals:
//   - Separate real display space from logical pattern space.
//   - Keep logical/real geometry identical (identity mapping) in v0.4.
//   - Make the pixel path timing-driven from the start.
//
// Fixed pipeline contract:
//   Display Space : 1 clock
//   Pattern Bank  : 4 clocks
//   Pattern Mixer : 4 clocks
//   Fade          : 1 clock
//   --------------------------------
//   Total         : 10 pixel clocks
//
// Throughput remains one pixel per clock after pipeline fill.
module asc_core (
    input  wire        clk,
    input  wire        reset_n,

    output wire        pclk,
    output wire        hsync,
    output wire        vsync,
    output wire        de,
    output wire [23:0] rgb,
    output wire [3:0]  debug
);

    // ------------------------------------------------------------------
    // Real display space / raster timing
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

    // Global frame / scene state in raster time.
    wire [8:0] frame_phase;
    wire [9:0] scene_frame_count;
    wire [7:0] pattern_mask;
    wire [1:0] mix_shift;

    timing_generator u_timing_generator (
        .clk            (clk),
        .reset_n        (reset_n),
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
        .reset_n     (reset_n),
        .frame_tick  (frame_tick),
        .frame_phase (frame_phase)
    );

    scene_controller u_scene_controller (
        .clk               (clk),
        .reset_n           (reset_n),
        .frame_tick        (frame_tick),
        .scene_frame_count (scene_frame_count),
        .pattern_mask      (pattern_mask),
        .mix_shift         (mix_shift)
    );

    // ------------------------------------------------------------------
    // DS: real display space -> logical display space (1 clock)
    // ------------------------------------------------------------------
    wire [9:0] logical_x;
    wire [9:0] logical_y;
    wire       logical_valid;

    display_space u_display_space (
        .clk            (clk),
        .reset_n        (reset_n),
        .physical_x     (physical_x),
        .physical_y     (physical_y),
        .physical_valid (physical_valid),
        .logical_x      (logical_x),
        .logical_y      (logical_y),
        .logical_valid  (logical_valid)
    );

    // Sideband state crossing the same display-space boundary.
    reg [8:0] frame_phase_ds;
    reg [9:0] scene_frame_count_ds;
    reg [7:0] pattern_mask_ds;
    reg [1:0] mix_shift_ds;

    always @(posedge clk) begin
        if (!reset_n) begin
            frame_phase_ds       <= 9'd0;
            scene_frame_count_ds <= 10'd0;
            pattern_mask_ds      <= 8'd0;
            mix_shift_ds         <= 2'd0;
        end else begin
            frame_phase_ds       <= frame_phase;
            scene_frame_count_ds <= scene_frame_count;
            pattern_mask_ds      <= pattern_mask;
            mix_shift_ds         <= mix_shift;
        end
    end

    // ------------------------------------------------------------------
    // P1..P4: pattern bank (4 clocks, one pixel/clock throughput)
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
        .reset_n         (reset_n),
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

    // pattern_mask / mix_shift must arrive at mixer input together with the
    // pattern RGB values, four clocks after the display-space boundary.
    reg [31:0] pattern_mask_pipe4;
    reg [7:0]  mix_shift_pipe4;

    always @(posedge clk) begin
        if (!reset_n) begin
            pattern_mask_pipe4 <= 32'd0;
            mix_shift_pipe4    <= 8'd0;
        end else begin
            pattern_mask_pipe4 <= {pattern_mask_pipe4[23:0], pattern_mask_ds};
            mix_shift_pipe4    <= {mix_shift_pipe4[5:0], mix_shift_ds};
        end
    end

    wire [7:0] mixer_pattern_mask = pattern_mask_pipe4[31:24];
    wire [1:0] mixer_mix_shift    = mix_shift_pipe4[7:6];

    // ------------------------------------------------------------------
    // M1..M4: mixer (4 clocks)
    // M3 registers normalized RGB; M4 performs Gray subtraction.
    // ------------------------------------------------------------------
    wire [23:0] mixed_rgb888;

    pattern_mixer u_pattern_mixer (
        .clk             (clk),
        .reset_n         (reset_n),
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

    // scene_frame_count is consumed by fade after Pattern(4)+Mixer(4).
    // Delay it eight clocks after the display-space boundary.
    reg [79:0] scene_frame_count_pipe8;

    always @(posedge clk) begin
        if (!reset_n)
            scene_frame_count_pipe8 <= 80'd0;
        else
            scene_frame_count_pipe8 <= {
                scene_frame_count_pipe8[69:0], scene_frame_count_ds
            };
    end

    wire [9:0] fade_scene_frame_count = scene_frame_count_pipe8[79:70];

    // ------------------------------------------------------------------
    // F1: fade (1 clock)
    // ------------------------------------------------------------------
    wire [23:0] faded_rgb888;

    fade_scaler u_fade_scaler (
        .clk               (clk),
        .reset_n           (reset_n),
        .scene_frame_count (fade_scene_frame_count),
        .mixed_rgb888      (mixed_rgb888),
        .faded_rgb888      (faded_rgb888)
    );

    // ------------------------------------------------------------------
    // Sync/DE sideband pipeline: exact total pixel latency = 10 clocks.
    // This keeps the delayed RGB pixel aligned with its original raster state.
    // ------------------------------------------------------------------
    reg [9:0] hsync_pipe10;
    reg [9:0] vsync_pipe10;
    reg [9:0] de_pipe10;

    always @(posedge clk) begin
        if (!reset_n) begin
            hsync_pipe10 <= 10'b1111111111;
            vsync_pipe10 <= 10'b1111111111;
            de_pipe10    <= 10'b0000000000;
        end else begin
            hsync_pipe10 <= {hsync_pipe10[8:0], timing_hsync};
            vsync_pipe10 <= {vsync_pipe10[8:0], timing_vsync};
            de_pipe10    <= {de_pipe10[8:0], timing_de};
        end
    end

    dpi_output u_dpi_output (
        .clk            (clk),
        .reset_n        (reset_n),
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
        .reset_n (reset_n),
        .h_count (h_count),
        .v_count (v_count),
        .de      (timing_de),
        .debug   (debug)
    );

endmodule
