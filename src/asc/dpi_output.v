`timescale 1ns / 1ps

// Platform-independent logical DPI output block for ASC v0.41.
// PCLK always runs. Until the 10-clock datapath is filled, output_valid keeps
// DE low, RGB black and syncs inactive-high.
module dpi_output (
    input  wire        clk,
    input  wire        output_valid,
    input  wire        timing_hsync,
    input  wire        timing_vsync,
    input  wire        timing_de,
    input  wire [23:0] pattern_rgb888,

    output wire        pclk,
    output wire        hsync,
    output wire        vsync,
    output wire        de,
    output wire [23:0] rgb
);

    assign pclk  = clk;
    assign hsync = output_valid ? timing_hsync : 1'b1;
    assign vsync = output_valid ? timing_vsync : 1'b1;
    assign de    = output_valid ? timing_de    : 1'b0;
    assign rgb   = (output_valid && timing_de) ? pattern_rgb888 : 24'h000000;

endmodule
