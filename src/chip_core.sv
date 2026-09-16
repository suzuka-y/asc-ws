// SPDX-FileCopyrightText: © 2025 XXX Authors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input  wire clk,       // clock
    input  wire rst_n,     // external reset from wafer.space pad (active low)

    input  wire [NUM_INPUT_PADS-1:0] input_in,   // Input value
    output wire [NUM_INPUT_PADS-1:0] input_pu,   // Pull-up
    output wire [NUM_INPUT_PADS-1:0] input_pd,   // Pull-down

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,   // Input value
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,  // Output value
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,   // Output enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,   // Input type (0=CMOS Buffer, 1=Schmitt Trigger)
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,   // Slew rate (0=fast, 1=slow)
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,   // Input enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,   // Pull-up
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,   // Pull-down

    inout  wire [NUM_ANALOG_PADS-1:0] analog      // Analog
);

    // ------------------------------------------------------------------
    // ASC v0.41 core
    //
    // rst_n is the raw asynchronous reset at the wafer.space/ASC boundary.
    // asc_core performs async-assert/sync-deassert synchronization internally
    // and does not distribute rst_n_raw beyond its reset synchronizer.
    // ------------------------------------------------------------------
    wire        asc_pclk;
    wire        asc_hsync;
    wire        asc_vsync;
    wire        asc_de;
    wire [23:0] asc_rgb;
    wire [3:0]  asc_debug;

    asc_core i_asc_core (
        .clk       (clk),
        .rst_n_raw (rst_n),
        .pclk      (asc_pclk),
        .hsync     (asc_hsync),
        .vsync     (asc_vsync),
        .de        (asc_de),
        .rgb       (asc_rgb),
        .debug     (asc_debug)
    );

    // ASC does not use the dedicated general-purpose input pads.
    assign input_pu = '0;
    assign input_pd = '0;

    // ------------------------------------------------------------------
    // wafer.space bidirectional pad mapping
    //
    // bidir[0]     : PCLK
    // bidir[1]     : HSYNC
    // bidir[2]     : VSYNC
    // bidir[3]     : DE
    // bidir[27:4]  : RGB[23:0]
    // bidir[31:28] : DEBUG[3:0]
    // bidir[*:32]  : reserved / unused
    // ------------------------------------------------------------------
    wire [31:0] asc_output_bus;

    assign asc_output_bus = {
        asc_debug,
        asc_rgb,
        asc_de,
        asc_vsync,
        asc_hsync,
        asc_pclk
    };

    assign bidir_out = {
        {(NUM_BIDIR_PADS-32){1'b0}},
        asc_output_bus
    };

    // Only the 32 ASC signals are driven. Remaining bidirectional pads are
    // left in input mode and reserved for future use.
    assign bidir_oe = {
        {(NUM_BIDIR_PADS-32){1'b0}},
        32'hFFFF_FFFF
    };

    assign bidir_cs = '0;
    assign bidir_sl = '0;
    assign bidir_ie = ~bidir_oe;
    assign bidir_pu = '0;
    assign bidir_pd = '0;

    // Consume currently unused digital inputs to avoid unused-signal noise.
    wire _unused;
    assign _unused = &{input_in, bidir_in};

endmodule

`default_nettype wire
