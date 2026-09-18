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

    input  wire clk,
    input  wire rst_n,

    input  wire [NUM_INPUT_PADS-1:0] input_in,
    output wire [NUM_INPUT_PADS-1:0] input_pu,
    output wire [NUM_INPUT_PADS-1:0] input_pd,

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,

    inout  wire [NUM_ANALOG_PADS-1:0] analog
);

    // ASC v0.43: 1280x720p60 RGB888, 74.25 MHz, 14-clock external-output pipeline.
    // rst_n is the raw asynchronous reset. asc_core synchronizes release.
    wire        asc_pclk;
    wire        asc_hsync;
    wire        asc_vsync;
    wire        asc_de;
    wire [23:0] asc_rgb;

    asc_core i_asc_core (
        .clk       (clk),
        .rst_n_raw (rst_n),
        .pclk      (asc_pclk),
        .hsync     (asc_hsync),
        .vsync     (asc_vsync),
        .de        (asc_de),
        .rgb       (asc_rgb)
    );

    assign input_pu = '0;
    assign input_pd = '0;

    // wafer.space bidirectional pad mapping:
    //   bidir[0]     = PCLK
    //   bidir[1]     = HSYNC
    //   bidir[2]     = VSYNC
    //   bidir[3]     = DE
    //   bidir[27:4]  = RGB[23:0]
    //   bidir[*:28]  = reserved / unused
    localparam integer ASC_OUTPUT_WIDTH = 28;
    wire [ASC_OUTPUT_WIDTH-1:0] asc_output_bus;

    assign asc_output_bus = {
        asc_rgb,
        asc_de,
        asc_vsync,
        asc_hsync,
        asc_pclk
    };

    assign bidir_out = {
        {(NUM_BIDIR_PADS-ASC_OUTPUT_WIDTH){1'b0}},
        asc_output_bus
    };

    assign bidir_oe = {
        {(NUM_BIDIR_PADS-ASC_OUTPUT_WIDTH){1'b0}},
        {ASC_OUTPUT_WIDTH{1'b1}}
    };

    assign bidir_cs = '0;
    assign bidir_sl = '0;  // fast output slew
    assign bidir_ie = ~bidir_oe;
    assign bidir_pu = '0;
    assign bidir_pd = '0;

    wire _unused;
    assign _unused = &{input_in, bidir_in};

endmodule

`default_nettype wire
